import CoreBluetooth
import Foundation
import Observation

@MainActor
@Observable
final class BluetoothHeartRateManager: NSObject {
    enum ConnectionState: Equatable {
        case bluetoothUnavailable
        case idle
        case scanning
        case deviceFound
        case connecting
        case connected
        case disconnected
        case connectionFailed(String)

        var title: String {
            switch self {
            case .bluetoothUnavailable:
                "Bluetooth unavailable"
            case .idle:
                "Ready to scan"
            case .scanning:
                "Scanning"
            case .deviceFound:
                "Device found"
            case .connecting:
                "Connecting"
            case .connected:
                "Connected"
            case .disconnected:
                "Disconnected"
            case .connectionFailed:
                "Connection failed"
            }
        }
    }

    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let name: String
        fileprivate let peripheral: CBPeripheral
    }

    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private(set) var connectionState: ConnectionState = .idle
    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var heartRate: Int?
    private(set) var selectedDeviceID: UUID?
    private(set) var isBluetoothAvailable = false

    private var centralManager: CBCentralManager!
    private var selectedPeripheral: CBPeripheral?
    private var userRequestedDisconnect = false
    private var reconnectAttempt = 0
    private let maximumReconnectDelay: TimeInterval = 8

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    var selectedDeviceName: String? {
        discoveredDevices.first(where: { $0.id == selectedDeviceID })?.name
            ?? selectedPeripheral?.name
    }

    func scan() {
        guard isBluetoothAvailable else {
            connectionState = .bluetoothUnavailable
            return
        }

        userRequestedDisconnect = false
        centralManager.stopScan()
        discoveredDevices.removeAll()
        selectedDeviceID = nil
        selectedPeripheral = nil
        heartRate = nil
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func selectDevice(id: UUID) {
        guard discoveredDevices.contains(where: { $0.id == id }) else {
            return
        }
        selectedDeviceID = id
    }

    func connect() {
        guard
            isBluetoothAvailable,
            let selectedDeviceID,
            let device = discoveredDevices.first(where: { $0.id == selectedDeviceID })
        else {
            return
        }

        centralManager.stopScan()
        selectedPeripheral = device.peripheral
        selectedPeripheral?.delegate = self
        userRequestedDisconnect = false
        reconnectAttempt = 0
        connectionState = .connecting
        centralManager.connect(device.peripheral)
    }

    func disconnect() {
        userRequestedDisconnect = true
        centralManager.stopScan()
        heartRate = nil

        guard let selectedPeripheral else {
            connectionState = .disconnected
            return
        }

        centralManager.cancelPeripheralConnection(selectedPeripheral)
    }

    func retry() {
        if selectedPeripheral != nil {
            userRequestedDisconnect = false
            reconnectAttempt = 0
            reconnect()
        } else {
            scan()
        }
    }

    private func reconnect() {
        guard
            isBluetoothAvailable,
            !userRequestedDisconnect,
            let selectedPeripheral
        else {
            return
        }

        connectionState = .connecting
        selectedPeripheral.delegate = self
        centralManager.connect(selectedPeripheral)
    }

    private func scheduleReconnect() {
        guard !userRequestedDisconnect else {
            return
        }

        reconnectAttempt += 1
        let delay = min(pow(2, Double(reconnectAttempt - 1)), maximumReconnectDelay)

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.connectionState == .disconnected else {
                return
            }
            self.reconnect()
        }
    }
}

extension BluetoothHeartRateManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothAvailable = central.state == .poweredOn

        switch central.state {
        case .poweredOn:
            if connectionState == .bluetoothUnavailable {
                connectionState = .idle
            }
        case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
            central.stopScan()
            heartRate = nil
            connectionState = .bluetoothUnavailable
        @unknown default:
            central.stopScan()
            heartRate = nil
            connectionState = .bluetoothUnavailable
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.id == peripheral.identifier }) else {
            return
        }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "Heart-rate device"
        discoveredDevices.append(
            DiscoveredDevice(id: peripheral.identifier, name: name, peripheral: peripheral)
        )
        discoveredDevices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if selectedDeviceID == nil {
            selectedDeviceID = peripheral.identifier
        }
        connectionState = .deviceFound
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        reconnectAttempt = 0
        peripheral.delegate = self
        peripheral.discoverServices([Self.heartRateServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        heartRate = nil
        connectionState = .connectionFailed(error?.localizedDescription ?? "Unable to connect.")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        heartRate = nil
        connectionState = .disconnected
        scheduleReconnect()
    }
}

extension BluetoothHeartRateManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            connectionState = .connectionFailed(error.localizedDescription)
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == Self.heartRateServiceUUID }) else {
            connectionState = .connectionFailed("The Heart Rate service was not found.")
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        if let error {
            connectionState = .connectionFailed(error.localizedDescription)
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == Self.heartRateMeasurementUUID
        }) else {
            connectionState = .connectionFailed("The Heart Rate Measurement characteristic was not found.")
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            connectionState = .connectionFailed(error.localizedDescription)
            return
        }

        if characteristic.uuid == Self.heartRateMeasurementUUID, characteristic.isNotifying {
            connectionState = .connected
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard
            error == nil,
            characteristic.uuid == Self.heartRateMeasurementUUID,
            let value = characteristic.value,
            let parsedHeartRate = try? HeartRateMeasurementParser.parse(value)
        else {
            return
        }

        heartRate = parsedHeartRate
    }
}
