// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MsdFilterOption _$MsdFilterOptionFromJson(Map<String, dynamic> json) =>
    MsdFilterOption(
      manufacturerId: (json['manufacturerId'] as num?)?.toInt() ?? 0,
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MsdFilterOptionToJson(MsdFilterOption instance) =>
    <String, dynamic>{
      'manufacturerId': instance.manufacturerId,
      'data': instance.data,
    };

ServiceDataFilterOption _$ServiceDataFilterOptionFromJson(
  Map<String, dynamic> json,
) => ServiceDataFilterOption(
  service: _serviceUuidFromJson(json['serviceUuid']),
  data:
      (json['data'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$ServiceDataFilterOptionToJson(
  ServiceDataFilterOption instance,
) => <String, dynamic>{
  'serviceUuid': _guidToJson(instance.service),
  'data': instance.data,
};

ScanOptions _$ScanOptionsFromJson(Map<String, dynamic> json) => ScanOptions(
  withServices: json['withServices'] == null
      ? const []
      : _guidListFromJson(json['withServices'] as List?),
  withRemoteIds:
      (json['withRemoteIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  withNames:
      (json['withNames'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  withKeywords:
      (json['withKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  withMsd:
      (json['withMsd'] as List<dynamic>?)
          ?.map((e) => MsdFilterOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  withServiceData:
      (json['withServiceData'] as List<dynamic>?)
          ?.map(
            (e) => ServiceDataFilterOption.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  timeout: _durationSecondsFromJson(json['timeout']),
  removeIfGone: _durationSecondsFromJson(json['removeIfGone']),
  continuousUpdates: json['continuousUpdates'] as bool? ?? false,
  continuousDivisor: (json['continuousDivisor'] as num?)?.toInt() ?? 1,
  oneByOne: json['oneByOne'] as bool? ?? false,
  androidLegacy: json['androidLegacy'] as bool? ?? false,
  androidScanMode: json['androidScanMode'] == null
      ? AndroidScanMode.lowLatency
      : _androidScanModeFromJson(json['androidScanMode']),
  androidUsesFineLocation: json['androidUsesFineLocation'] as bool? ?? false,
  androidCheckLocationServices:
      json['androidCheckLocationServices'] as bool? ?? true,
  webOptionalServices: json['webOptionalServices'] == null
      ? const []
      : _guidListFromJson(json['webOptionalServices'] as List?),
);

Map<String, dynamic> _$ScanOptionsToJson(ScanOptions instance) =>
    <String, dynamic>{
      'withServices': _guidListToJson(instance.withServices),
      'withRemoteIds': instance.withRemoteIds,
      'withNames': instance.withNames,
      'withKeywords': instance.withKeywords,
      'withMsd': instance.withMsd,
      'withServiceData': instance.withServiceData,
      'timeout': _durationSecondsToJson(instance.timeout),
      'removeIfGone': _durationSecondsToJson(instance.removeIfGone),
      'continuousUpdates': instance.continuousUpdates,
      'continuousDivisor': instance.continuousDivisor,
      'oneByOne': instance.oneByOne,
      'androidLegacy': instance.androidLegacy,
      'androidScanMode': _androidScanModeToJson(instance.androidScanMode),
      'androidUsesFineLocation': instance.androidUsesFineLocation,
      'androidCheckLocationServices': instance.androidCheckLocationServices,
      'webOptionalServices': _guidListToJson(instance.webOptionalServices),
    };

SetOptions _$SetOptionsFromJson(Map<String, dynamic> json) => SetOptions(
  showPowerAlert: json['showPowerAlert'] as bool? ?? true,
  restoreState: json['restoreState'] as bool? ?? false,
);

Map<String, dynamic> _$SetOptionsToJson(SetOptions instance) =>
    <String, dynamic>{
      'showPowerAlert': instance.showPowerAlert,
      'restoreState': instance.restoreState,
    };

ConnectOptions _$ConnectOptionsFromJson(Map<String, dynamic> json) =>
    ConnectOptions(
      timeout: json['timeout'] == null
          ? const Duration(seconds: 35)
          : _connectTimeoutFromJson(json['timeout']),
      mtu: (json['mtu'] as num?)?.toInt() ?? 512,
      autoConnect: json['autoConnect'] as bool? ?? false,
      license: json['license'] == null
          ? License.free
          : _licenseFromJson(json['license']),
    );

Map<String, dynamic> _$ConnectOptionsToJson(ConnectOptions instance) =>
    <String, dynamic>{
      'timeout': _durationSecondsToJson(instance.timeout),
      'mtu': instance.mtu,
      'autoConnect': instance.autoConnect,
      'license': _licenseToJson(instance.license),
    };

DisconnectOptions _$DisconnectOptionsFromJson(Map<String, dynamic> json) =>
    DisconnectOptions(
      timeout: (json['timeout'] as num?)?.toInt() ?? 35,
      queue: json['queue'] as bool? ?? true,
      androidDelay: (json['androidDelay'] as num?)?.toInt() ?? 2000,
    );

Map<String, dynamic> _$DisconnectOptionsToJson(DisconnectOptions instance) =>
    <String, dynamic>{
      'timeout': instance.timeout,
      'queue': instance.queue,
      'androidDelay': instance.androidDelay,
    };

DiscoverServicesOptions _$DiscoverServicesOptionsFromJson(
  Map<String, dynamic> json,
) => DiscoverServicesOptions(
  subscribeToServicesChanged:
      json['subscribeToServicesChanged'] as bool? ?? false,
  timeout: (json['timeout'] as num?)?.toInt() ?? 15,
);

Map<String, dynamic> _$DiscoverServicesOptionsToJson(
  DiscoverServicesOptions instance,
) => <String, dynamic>{
  'subscribeToServicesChanged': instance.subscribeToServicesChanged,
  'timeout': instance.timeout,
};

ReadCharacteristicOptions _$ReadCharacteristicOptionsFromJson(
  Map<String, dynamic> json,
) => ReadCharacteristicOptions(
  timeout: (json['timeout'] as num?)?.toInt() ?? 15,
);

Map<String, dynamic> _$ReadCharacteristicOptionsToJson(
  ReadCharacteristicOptions instance,
) => <String, dynamic>{'timeout': instance.timeout};

WriteCharacteristicOptions _$WriteCharacteristicOptionsFromJson(
  Map<String, dynamic> json,
) => WriteCharacteristicOptions(
  withoutResponse: json['withoutResponse'] as bool? ?? false,
  allowLongWrite: json['allowLongWrite'] as bool? ?? false,
  timeout: (json['timeout'] as num?)?.toInt() ?? 15,
);

Map<String, dynamic> _$WriteCharacteristicOptionsToJson(
  WriteCharacteristicOptions instance,
) => <String, dynamic>{
  'withoutResponse': instance.withoutResponse,
  'allowLongWrite': instance.allowLongWrite,
  'timeout': instance.timeout,
};

NotifyCharacteristicOptions _$NotifyCharacteristicOptionsFromJson(
  Map<String, dynamic> json,
) => NotifyCharacteristicOptions(
  timeout: (json['timeout'] as num?)?.toInt() ?? 15,
  forceIndications: json['forceIndications'] as bool? ?? false,
);

Map<String, dynamic> _$NotifyCharacteristicOptionsToJson(
  NotifyCharacteristicOptions instance,
) => <String, dynamic>{
  'timeout': instance.timeout,
  'forceIndications': instance.forceIndications,
};
