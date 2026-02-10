// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvertisementDataDto _$AdvertisementDataDtoFromJson(
  Map<String, dynamic> json,
) => AdvertisementDataDto(
  advName: json['advName'] as String,
  txPowerLevel: (json['txPowerLevel'] as num?)?.toInt(),
  appearance: (json['appearance'] as num?)?.toInt(),
  connectable: json['connectable'] as bool,
  manufacturerData: (json['manufacturerData'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
    ),
  ),
  serviceData: (json['serviceData'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
    ),
  ),
  serviceUuids: (json['serviceUuids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$AdvertisementDataDtoToJson(
  AdvertisementDataDto instance,
) => <String, dynamic>{
  'advName': instance.advName,
  'txPowerLevel': instance.txPowerLevel,
  'appearance': instance.appearance,
  'connectable': instance.connectable,
  'manufacturerData': instance.manufacturerData,
  'serviceData': instance.serviceData,
  'serviceUuids': instance.serviceUuids,
};

ScanResultDto _$ScanResultDtoFromJson(Map<String, dynamic> json) =>
    ScanResultDto(
      remoteId: json['remoteId'] as String,
      rssi: (json['rssi'] as num).toInt(),
      advertisementData: AdvertisementDataDto.fromJson(
        json['advertisementData'] as Map<String, dynamic>,
      ),
      timestampMs: (json['timestamp_ms'] as num).toInt(),
    );

Map<String, dynamic> _$ScanResultDtoToJson(ScanResultDto instance) =>
    <String, dynamic>{
      'remoteId': instance.remoteId,
      'rssi': instance.rssi,
      'advertisementData': instance.advertisementData.toJson(),
      'timestamp_ms': instance.timestampMs,
    };

BluetoothDeviceDto _$BluetoothDeviceDtoFromJson(Map<String, dynamic> json) =>
    BluetoothDeviceDto(
      remoteId: json['remoteId'] as String,
      platformName: json['platformName'] as String,
      advName: json['advName'] as String,
      isConnected: json['isConnected'] as bool,
      mtuNow: (json['mtuNow'] as num).toInt(),
    );

Map<String, dynamic> _$BluetoothDeviceDtoToJson(BluetoothDeviceDto instance) =>
    <String, dynamic>{
      'remoteId': instance.remoteId,
      'platformName': instance.platformName,
      'advName': instance.advName,
      'isConnected': instance.isConnected,
      'mtuNow': instance.mtuNow,
    };

DisconnectReasonDto _$DisconnectReasonDtoFromJson(Map<String, dynamic> json) =>
    DisconnectReasonDto(
      platform: json['platform'] as String,
      code: (json['code'] as num?)?.toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$DisconnectReasonDtoToJson(
  DisconnectReasonDto instance,
) => <String, dynamic>{
  'platform': instance.platform,
  'code': instance.code,
  'description': instance.description,
};

CharacteristicPropertiesDto _$CharacteristicPropertiesDtoFromJson(
  Map<String, dynamic> json,
) => CharacteristicPropertiesDto(
  broadcast: json['broadcast'] as bool,
  read: json['read'] as bool,
  writeWithoutResponse: json['writeWithoutResponse'] as bool,
  write: json['write'] as bool,
  notify: json['notify'] as bool,
  indicate: json['indicate'] as bool,
  authenticatedSignedWrites: json['authenticatedSignedWrites'] as bool,
  extendedProperties: json['extendedProperties'] as bool,
  notifyEncryptionRequired: json['notifyEncryptionRequired'] as bool,
  indicateEncryptionRequired: json['indicateEncryptionRequired'] as bool,
);

Map<String, dynamic> _$CharacteristicPropertiesDtoToJson(
  CharacteristicPropertiesDto instance,
) => <String, dynamic>{
  'broadcast': instance.broadcast,
  'read': instance.read,
  'writeWithoutResponse': instance.writeWithoutResponse,
  'write': instance.write,
  'notify': instance.notify,
  'indicate': instance.indicate,
  'authenticatedSignedWrites': instance.authenticatedSignedWrites,
  'extendedProperties': instance.extendedProperties,
  'notifyEncryptionRequired': instance.notifyEncryptionRequired,
  'indicateEncryptionRequired': instance.indicateEncryptionRequired,
};

BluetoothDescriptorDto _$BluetoothDescriptorDtoFromJson(
  Map<String, dynamic> json,
) => BluetoothDescriptorDto(
  uuid: json['uuid'] as String,
  remoteId: json['remoteId'] as String,
  serviceUuid: json['serviceUuid'] as String,
  characteristicUuid: json['characteristicUuid'] as String,
  primaryServiceUuid: json['primaryServiceUuid'] as String?,
  lastValue: (json['lastValue'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$BluetoothDescriptorDtoToJson(
  BluetoothDescriptorDto instance,
) => <String, dynamic>{
  'uuid': instance.uuid,
  'remoteId': instance.remoteId,
  'serviceUuid': instance.serviceUuid,
  'characteristicUuid': instance.characteristicUuid,
  'primaryServiceUuid': instance.primaryServiceUuid,
  'lastValue': instance.lastValue,
};

BluetoothCharacteristicDto _$BluetoothCharacteristicDtoFromJson(
  Map<String, dynamic> json,
) => BluetoothCharacteristicDto(
  uuid: json['uuid'] as String,
  remoteId: json['remoteId'] as String,
  serviceUuid: json['serviceUuid'] as String,
  properties: CharacteristicPropertiesDto.fromJson(
    json['properties'] as Map<String, dynamic>,
  ),
  descriptors: (json['descriptors'] as List<dynamic>)
      .map((e) => BluetoothDescriptorDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  isNotifying: json['isNotifying'] as bool,
  lastValue: (json['lastValue'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$BluetoothCharacteristicDtoToJson(
  BluetoothCharacteristicDto instance,
) => <String, dynamic>{
  'uuid': instance.uuid,
  'remoteId': instance.remoteId,
  'serviceUuid': instance.serviceUuid,
  'properties': instance.properties.toJson(),
  'descriptors': instance.descriptors.map((e) => e.toJson()).toList(),
  'isNotifying': instance.isNotifying,
  'lastValue': instance.lastValue,
};

BluetoothServiceDto _$BluetoothServiceDtoFromJson(Map<String, dynamic> json) =>
    BluetoothServiceDto(
      uuid: json['uuid'] as String,
      remoteId: json['remoteId'] as String,
      primaryServiceUuid: json['primaryServiceUuid'] as String?,
      characteristics: (json['characteristics'] as List<dynamic>)
          .map(
            (e) =>
                BluetoothCharacteristicDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$BluetoothServiceDtoToJson(
  BluetoothServiceDto instance,
) => <String, dynamic>{
  'uuid': instance.uuid,
  'remoteId': instance.remoteId,
  'primaryServiceUuid': instance.primaryServiceUuid,
  'characteristics': instance.characteristics.map((e) => e.toJson()).toList(),
};
