// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_store.dart';

// ignore_for_file: type=lint
class $IdentitiesTable extends Identities
    with TableInfo<$IdentitiesTable, Identity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _callsignMeta = const VerificationMeta(
    'callsign',
  );
  @override
  late final GeneratedColumn<String> callsign = GeneratedColumn<String>(
    'callsign',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeBbsMeta = const VerificationMeta(
    'homeBbs',
  );
  @override
  late final GeneratedColumn<String> homeBbs = GeneratedColumn<String>(
    'home_bbs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, callsign, name, homeBbs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Identity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('callsign')) {
      context.handle(
        _callsignMeta,
        callsign.isAcceptableOrUnknown(data['callsign']!, _callsignMeta),
      );
    } else if (isInserting) {
      context.missing(_callsignMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('home_bbs')) {
      context.handle(
        _homeBbsMeta,
        homeBbs.isAcceptableOrUnknown(data['home_bbs']!, _homeBbsMeta),
      );
    } else if (isInserting) {
      context.missing(_homeBbsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Identity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Identity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      callsign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}callsign'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      homeBbs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_bbs'],
      )!,
    );
  }

  @override
  $IdentitiesTable createAlias(String alias) {
    return $IdentitiesTable(attachedDatabase, alias);
  }
}

class Identity extends DataClass implements Insertable<Identity> {
  final int id;
  final String callsign;
  final String name;

  /// Full hierarchical address of our home BBS, for example GB7RDG.#42.GBR.EURO.
  final String homeBbs;
  const Identity({
    required this.id,
    required this.callsign,
    required this.name,
    required this.homeBbs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['callsign'] = Variable<String>(callsign);
    map['name'] = Variable<String>(name);
    map['home_bbs'] = Variable<String>(homeBbs);
    return map;
  }

  IdentitiesCompanion toCompanion(bool nullToAbsent) {
    return IdentitiesCompanion(
      id: Value(id),
      callsign: Value(callsign),
      name: Value(name),
      homeBbs: Value(homeBbs),
    );
  }

  factory Identity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Identity(
      id: serializer.fromJson<int>(json['id']),
      callsign: serializer.fromJson<String>(json['callsign']),
      name: serializer.fromJson<String>(json['name']),
      homeBbs: serializer.fromJson<String>(json['homeBbs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'callsign': serializer.toJson<String>(callsign),
      'name': serializer.toJson<String>(name),
      'homeBbs': serializer.toJson<String>(homeBbs),
    };
  }

  Identity copyWith({
    int? id,
    String? callsign,
    String? name,
    String? homeBbs,
  }) => Identity(
    id: id ?? this.id,
    callsign: callsign ?? this.callsign,
    name: name ?? this.name,
    homeBbs: homeBbs ?? this.homeBbs,
  );
  Identity copyWithCompanion(IdentitiesCompanion data) {
    return Identity(
      id: data.id.present ? data.id.value : this.id,
      callsign: data.callsign.present ? data.callsign.value : this.callsign,
      name: data.name.present ? data.name.value : this.name,
      homeBbs: data.homeBbs.present ? data.homeBbs.value : this.homeBbs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Identity(')
          ..write('id: $id, ')
          ..write('callsign: $callsign, ')
          ..write('name: $name, ')
          ..write('homeBbs: $homeBbs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, callsign, name, homeBbs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Identity &&
          other.id == this.id &&
          other.callsign == this.callsign &&
          other.name == this.name &&
          other.homeBbs == this.homeBbs);
}

class IdentitiesCompanion extends UpdateCompanion<Identity> {
  final Value<int> id;
  final Value<String> callsign;
  final Value<String> name;
  final Value<String> homeBbs;
  const IdentitiesCompanion({
    this.id = const Value.absent(),
    this.callsign = const Value.absent(),
    this.name = const Value.absent(),
    this.homeBbs = const Value.absent(),
  });
  IdentitiesCompanion.insert({
    this.id = const Value.absent(),
    required String callsign,
    required String name,
    required String homeBbs,
  }) : callsign = Value(callsign),
       name = Value(name),
       homeBbs = Value(homeBbs);
  static Insertable<Identity> custom({
    Expression<int>? id,
    Expression<String>? callsign,
    Expression<String>? name,
    Expression<String>? homeBbs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (callsign != null) 'callsign': callsign,
      if (name != null) 'name': name,
      if (homeBbs != null) 'home_bbs': homeBbs,
    });
  }

  IdentitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? callsign,
    Value<String>? name,
    Value<String>? homeBbs,
  }) {
    return IdentitiesCompanion(
      id: id ?? this.id,
      callsign: callsign ?? this.callsign,
      name: name ?? this.name,
      homeBbs: homeBbs ?? this.homeBbs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (callsign.present) {
      map['callsign'] = Variable<String>(callsign.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (homeBbs.present) {
      map['home_bbs'] = Variable<String>(homeBbs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('callsign: $callsign, ')
          ..write('name: $name, ')
          ..write('homeBbs: $homeBbs')
          ..write(')'))
        .toString();
  }
}

class $ConnectionsTable extends Connections
    with TableInfo<$ConnectionsTable, Connection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bbsTypeMeta = const VerificationMeta(
    'bbsType',
  );
  @override
  late final GeneratedColumn<String> bbsType = GeneratedColumn<String>(
    'bbs_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portKindMeta = const VerificationMeta(
    'portKind',
  );
  @override
  late final GeneratedColumn<String> portKind = GeneratedColumn<String>(
    'port_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loginNameMeta = const VerificationMeta(
    'loginName',
  );
  @override
  late final GeneratedColumn<String> loginName = GeneratedColumn<String>(
    'login_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personalDownloadMeta = const VerificationMeta(
    'personalDownload',
  );
  @override
  late final GeneratedColumn<String> personalDownload = GeneratedColumn<String>(
    'personal_download',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('onOpen'),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncResultMeta = const VerificationMeta(
    'lastSyncResult',
  );
  @override
  late final GeneratedColumn<String> lastSyncResult = GeneratedColumn<String>(
    'last_sync_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    bbsType,
    host,
    port,
    portKind,
    loginName,
    personalDownload,
    lastSyncAt,
    lastSyncResult,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Connection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bbs_type')) {
      context.handle(
        _bbsTypeMeta,
        bbsType.isAcceptableOrUnknown(data['bbs_type']!, _bbsTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_bbsTypeMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('port_kind')) {
      context.handle(
        _portKindMeta,
        portKind.isAcceptableOrUnknown(data['port_kind']!, _portKindMeta),
      );
    } else if (isInserting) {
      context.missing(_portKindMeta);
    }
    if (data.containsKey('login_name')) {
      context.handle(
        _loginNameMeta,
        loginName.isAcceptableOrUnknown(data['login_name']!, _loginNameMeta),
      );
    } else if (isInserting) {
      context.missing(_loginNameMeta);
    }
    if (data.containsKey('personal_download')) {
      context.handle(
        _personalDownloadMeta,
        personalDownload.isAcceptableOrUnknown(
          data['personal_download']!,
          _personalDownloadMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_result')) {
      context.handle(
        _lastSyncResultMeta,
        lastSyncResult.isAcceptableOrUnknown(
          data['last_sync_result']!,
          _lastSyncResultMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Connection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Connection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bbsType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bbs_type'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      portKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}port_kind'],
      )!,
      loginName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_name'],
      )!,
      personalDownload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_download'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastSyncResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sync_result'],
      ),
    );
  }

  @override
  $ConnectionsTable createAlias(String alias) {
    return $ConnectionsTable(attachedDatabase, alias);
  }
}

class Connection extends DataClass implements Insertable<Connection> {
  final int id;
  final String name;

  /// Which driver: 'bpq' or 'xrouter'.
  final String bbsType;
  final String host;
  final int port;

  /// For bpq: 'fbb' or 'telnet'. Always 'telnet' for xrouter.
  final String portKind;
  final String loginName;

  /// When personal mail downloads: 'onOpen' (only when opened, so the BBS's
  /// read marker stays true) or 'atSync' (everything, for reading offline).
  final String personalDownload;
  final DateTime? lastSyncAt;

  /// Plain words: "Fetched 3 new messages" or what went wrong.
  final String? lastSyncResult;
  const Connection({
    required this.id,
    required this.name,
    required this.bbsType,
    required this.host,
    required this.port,
    required this.portKind,
    required this.loginName,
    required this.personalDownload,
    this.lastSyncAt,
    this.lastSyncResult,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['bbs_type'] = Variable<String>(bbsType);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['port_kind'] = Variable<String>(portKind);
    map['login_name'] = Variable<String>(loginName);
    map['personal_download'] = Variable<String>(personalDownload);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || lastSyncResult != null) {
      map['last_sync_result'] = Variable<String>(lastSyncResult);
    }
    return map;
  }

  ConnectionsCompanion toCompanion(bool nullToAbsent) {
    return ConnectionsCompanion(
      id: Value(id),
      name: Value(name),
      bbsType: Value(bbsType),
      host: Value(host),
      port: Value(port),
      portKind: Value(portKind),
      loginName: Value(loginName),
      personalDownload: Value(personalDownload),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastSyncResult: lastSyncResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncResult),
    );
  }

  factory Connection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Connection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bbsType: serializer.fromJson<String>(json['bbsType']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      portKind: serializer.fromJson<String>(json['portKind']),
      loginName: serializer.fromJson<String>(json['loginName']),
      personalDownload: serializer.fromJson<String>(json['personalDownload']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastSyncResult: serializer.fromJson<String?>(json['lastSyncResult']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'bbsType': serializer.toJson<String>(bbsType),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'portKind': serializer.toJson<String>(portKind),
      'loginName': serializer.toJson<String>(loginName),
      'personalDownload': serializer.toJson<String>(personalDownload),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastSyncResult': serializer.toJson<String?>(lastSyncResult),
    };
  }

  Connection copyWith({
    int? id,
    String? name,
    String? bbsType,
    String? host,
    int? port,
    String? portKind,
    String? loginName,
    String? personalDownload,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> lastSyncResult = const Value.absent(),
  }) => Connection(
    id: id ?? this.id,
    name: name ?? this.name,
    bbsType: bbsType ?? this.bbsType,
    host: host ?? this.host,
    port: port ?? this.port,
    portKind: portKind ?? this.portKind,
    loginName: loginName ?? this.loginName,
    personalDownload: personalDownload ?? this.personalDownload,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastSyncResult: lastSyncResult.present
        ? lastSyncResult.value
        : this.lastSyncResult,
  );
  Connection copyWithCompanion(ConnectionsCompanion data) {
    return Connection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bbsType: data.bbsType.present ? data.bbsType.value : this.bbsType,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      portKind: data.portKind.present ? data.portKind.value : this.portKind,
      loginName: data.loginName.present ? data.loginName.value : this.loginName,
      personalDownload: data.personalDownload.present
          ? data.personalDownload.value
          : this.personalDownload,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastSyncResult: data.lastSyncResult.present
          ? data.lastSyncResult.value
          : this.lastSyncResult,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Connection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bbsType: $bbsType, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('portKind: $portKind, ')
          ..write('loginName: $loginName, ')
          ..write('personalDownload: $personalDownload, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncResult: $lastSyncResult')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bbsType,
    host,
    port,
    portKind,
    loginName,
    personalDownload,
    lastSyncAt,
    lastSyncResult,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Connection &&
          other.id == this.id &&
          other.name == this.name &&
          other.bbsType == this.bbsType &&
          other.host == this.host &&
          other.port == this.port &&
          other.portKind == this.portKind &&
          other.loginName == this.loginName &&
          other.personalDownload == this.personalDownload &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastSyncResult == this.lastSyncResult);
}

class ConnectionsCompanion extends UpdateCompanion<Connection> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> bbsType;
  final Value<String> host;
  final Value<int> port;
  final Value<String> portKind;
  final Value<String> loginName;
  final Value<String> personalDownload;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastSyncResult;
  const ConnectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bbsType = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.portKind = const Value.absent(),
    this.loginName = const Value.absent(),
    this.personalDownload = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastSyncResult = const Value.absent(),
  });
  ConnectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String bbsType,
    required String host,
    required int port,
    required String portKind,
    required String loginName,
    this.personalDownload = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastSyncResult = const Value.absent(),
  }) : name = Value(name),
       bbsType = Value(bbsType),
       host = Value(host),
       port = Value(port),
       portKind = Value(portKind),
       loginName = Value(loginName);
  static Insertable<Connection> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? bbsType,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? portKind,
    Expression<String>? loginName,
    Expression<String>? personalDownload,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastSyncResult,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bbsType != null) 'bbs_type': bbsType,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (portKind != null) 'port_kind': portKind,
      if (loginName != null) 'login_name': loginName,
      if (personalDownload != null) 'personal_download': personalDownload,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastSyncResult != null) 'last_sync_result': lastSyncResult,
    });
  }

  ConnectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? bbsType,
    Value<String>? host,
    Value<int>? port,
    Value<String>? portKind,
    Value<String>? loginName,
    Value<String>? personalDownload,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? lastSyncResult,
  }) {
    return ConnectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bbsType: bbsType ?? this.bbsType,
      host: host ?? this.host,
      port: port ?? this.port,
      portKind: portKind ?? this.portKind,
      loginName: loginName ?? this.loginName,
      personalDownload: personalDownload ?? this.personalDownload,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bbsType.present) {
      map['bbs_type'] = Variable<String>(bbsType.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (portKind.present) {
      map['port_kind'] = Variable<String>(portKind.value);
    }
    if (loginName.present) {
      map['login_name'] = Variable<String>(loginName.value);
    }
    if (personalDownload.present) {
      map['personal_download'] = Variable<String>(personalDownload.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastSyncResult.present) {
      map['last_sync_result'] = Variable<String>(lastSyncResult.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bbsType: $bbsType, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('portKind: $portKind, ')
          ..write('loginName: $loginName, ')
          ..write('personalDownload: $personalDownload, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncResult: $lastSyncResult')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<int> connectionId = GeneratedColumn<int>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES connections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bbsNumberMeta = const VerificationMeta(
    'bbsNumber',
  );
  @override
  late final GeneratedColumn<int> bbsNumber = GeneratedColumn<int>(
    'bbs_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromCallMeta = const VerificationMeta(
    'fromCall',
  );
  @override
  late final GeneratedColumn<String> fromCall = GeneratedColumn<String>(
    'from_call',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toCallMeta = const VerificationMeta('toCall');
  @override
  late final GeneratedColumn<String> toCall = GeneratedColumn<String>(
    'to_call',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bidMeta = const VerificationMeta('bid');
  @override
  late final GeneratedColumn<String> bid = GeneratedColumn<String>(
    'bid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routingMeta = const VerificationMeta(
    'routing',
  );
  @override
  late final GeneratedColumn<String> routing = GeneratedColumn<String>(
    'routing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingKillMeta = const VerificationMeta(
    'pendingKill',
  );
  @override
  late final GeneratedColumn<bool> pendingKill = GeneratedColumn<bool>(
    'pending_kill',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_kill" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastListedAtMeta = const VerificationMeta(
    'lastListedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastListedAt = GeneratedColumn<DateTime>(
    'last_listed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    connectionId,
    bbsNumber,
    type,
    fromCall,
    toCall,
    at,
    subject,
    date,
    size,
    bid,
    body,
    routing,
    read,
    starred,
    pendingKill,
    lastListedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('bbs_number')) {
      context.handle(
        _bbsNumberMeta,
        bbsNumber.isAcceptableOrUnknown(data['bbs_number']!, _bbsNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_bbsNumberMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('from_call')) {
      context.handle(
        _fromCallMeta,
        fromCall.isAcceptableOrUnknown(data['from_call']!, _fromCallMeta),
      );
    } else if (isInserting) {
      context.missing(_fromCallMeta);
    }
    if (data.containsKey('to_call')) {
      context.handle(
        _toCallMeta,
        toCall.isAcceptableOrUnknown(data['to_call']!, _toCallMeta),
      );
    } else if (isInserting) {
      context.missing(_toCallMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('bid')) {
      context.handle(
        _bidMeta,
        bid.isAcceptableOrUnknown(data['bid']!, _bidMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('routing')) {
      context.handle(
        _routingMeta,
        routing.isAcceptableOrUnknown(data['routing']!, _routingMeta),
      );
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('pending_kill')) {
      context.handle(
        _pendingKillMeta,
        pendingKill.isAcceptableOrUnknown(
          data['pending_kill']!,
          _pendingKillMeta,
        ),
      );
    }
    if (data.containsKey('last_listed_at')) {
      context.handle(
        _lastListedAtMeta,
        lastListedAt.isAcceptableOrUnknown(
          data['last_listed_at']!,
          _lastListedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastListedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {connectionId, bbsNumber},
  ];
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connection_id'],
      )!,
      bbsNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bbs_number'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      fromCall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_call'],
      )!,
      toCall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_call'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}at'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      bid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bid'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      routing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routing'],
      ),
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      pendingKill: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_kill'],
      )!,
      lastListedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_listed_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int connectionId;

  /// The BBS's number. Only meaningful on that connection.
  final int bbsNumber;

  /// 'personal', 'bulletin' or 'traffic' (shown as personal).
  final String type;
  final String fromCall;
  final String toCall;
  final String? at;
  final String subject;
  final DateTime date;
  final int? size;
  final String? bid;

  /// Null until fetched; bulletins outside a subscription stay headers only.
  final String? body;

  /// R: lines, one per line.
  final String? routing;

  /// Our own read state, separate from the BBS's.
  final bool read;
  final bool starred;

  /// Deleted here; kill on the BBS at the next sync, then remove the row.
  final bool pendingKill;

  /// Last time the BBS listed it. Rows the BBS stops listing are removed
  /// unless their text is here (additive, docs/plan.md Sync rules).
  final DateTime lastListedAt;
  const Message({
    required this.id,
    required this.connectionId,
    required this.bbsNumber,
    required this.type,
    required this.fromCall,
    required this.toCall,
    this.at,
    required this.subject,
    required this.date,
    this.size,
    this.bid,
    this.body,
    this.routing,
    required this.read,
    required this.starred,
    required this.pendingKill,
    required this.lastListedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['connection_id'] = Variable<int>(connectionId);
    map['bbs_number'] = Variable<int>(bbsNumber);
    map['type'] = Variable<String>(type);
    map['from_call'] = Variable<String>(fromCall);
    map['to_call'] = Variable<String>(toCall);
    if (!nullToAbsent || at != null) {
      map['at'] = Variable<String>(at);
    }
    map['subject'] = Variable<String>(subject);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || bid != null) {
      map['bid'] = Variable<String>(bid);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || routing != null) {
      map['routing'] = Variable<String>(routing);
    }
    map['read'] = Variable<bool>(read);
    map['starred'] = Variable<bool>(starred);
    map['pending_kill'] = Variable<bool>(pendingKill);
    map['last_listed_at'] = Variable<DateTime>(lastListedAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      connectionId: Value(connectionId),
      bbsNumber: Value(bbsNumber),
      type: Value(type),
      fromCall: Value(fromCall),
      toCall: Value(toCall),
      at: at == null && nullToAbsent ? const Value.absent() : Value(at),
      subject: Value(subject),
      date: Value(date),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      bid: bid == null && nullToAbsent ? const Value.absent() : Value(bid),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      routing: routing == null && nullToAbsent
          ? const Value.absent()
          : Value(routing),
      read: Value(read),
      starred: Value(starred),
      pendingKill: Value(pendingKill),
      lastListedAt: Value(lastListedAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      connectionId: serializer.fromJson<int>(json['connectionId']),
      bbsNumber: serializer.fromJson<int>(json['bbsNumber']),
      type: serializer.fromJson<String>(json['type']),
      fromCall: serializer.fromJson<String>(json['fromCall']),
      toCall: serializer.fromJson<String>(json['toCall']),
      at: serializer.fromJson<String?>(json['at']),
      subject: serializer.fromJson<String>(json['subject']),
      date: serializer.fromJson<DateTime>(json['date']),
      size: serializer.fromJson<int?>(json['size']),
      bid: serializer.fromJson<String?>(json['bid']),
      body: serializer.fromJson<String?>(json['body']),
      routing: serializer.fromJson<String?>(json['routing']),
      read: serializer.fromJson<bool>(json['read']),
      starred: serializer.fromJson<bool>(json['starred']),
      pendingKill: serializer.fromJson<bool>(json['pendingKill']),
      lastListedAt: serializer.fromJson<DateTime>(json['lastListedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'connectionId': serializer.toJson<int>(connectionId),
      'bbsNumber': serializer.toJson<int>(bbsNumber),
      'type': serializer.toJson<String>(type),
      'fromCall': serializer.toJson<String>(fromCall),
      'toCall': serializer.toJson<String>(toCall),
      'at': serializer.toJson<String?>(at),
      'subject': serializer.toJson<String>(subject),
      'date': serializer.toJson<DateTime>(date),
      'size': serializer.toJson<int?>(size),
      'bid': serializer.toJson<String?>(bid),
      'body': serializer.toJson<String?>(body),
      'routing': serializer.toJson<String?>(routing),
      'read': serializer.toJson<bool>(read),
      'starred': serializer.toJson<bool>(starred),
      'pendingKill': serializer.toJson<bool>(pendingKill),
      'lastListedAt': serializer.toJson<DateTime>(lastListedAt),
    };
  }

  Message copyWith({
    int? id,
    int? connectionId,
    int? bbsNumber,
    String? type,
    String? fromCall,
    String? toCall,
    Value<String?> at = const Value.absent(),
    String? subject,
    DateTime? date,
    Value<int?> size = const Value.absent(),
    Value<String?> bid = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<String?> routing = const Value.absent(),
    bool? read,
    bool? starred,
    bool? pendingKill,
    DateTime? lastListedAt,
  }) => Message(
    id: id ?? this.id,
    connectionId: connectionId ?? this.connectionId,
    bbsNumber: bbsNumber ?? this.bbsNumber,
    type: type ?? this.type,
    fromCall: fromCall ?? this.fromCall,
    toCall: toCall ?? this.toCall,
    at: at.present ? at.value : this.at,
    subject: subject ?? this.subject,
    date: date ?? this.date,
    size: size.present ? size.value : this.size,
    bid: bid.present ? bid.value : this.bid,
    body: body.present ? body.value : this.body,
    routing: routing.present ? routing.value : this.routing,
    read: read ?? this.read,
    starred: starred ?? this.starred,
    pendingKill: pendingKill ?? this.pendingKill,
    lastListedAt: lastListedAt ?? this.lastListedAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      bbsNumber: data.bbsNumber.present ? data.bbsNumber.value : this.bbsNumber,
      type: data.type.present ? data.type.value : this.type,
      fromCall: data.fromCall.present ? data.fromCall.value : this.fromCall,
      toCall: data.toCall.present ? data.toCall.value : this.toCall,
      at: data.at.present ? data.at.value : this.at,
      subject: data.subject.present ? data.subject.value : this.subject,
      date: data.date.present ? data.date.value : this.date,
      size: data.size.present ? data.size.value : this.size,
      bid: data.bid.present ? data.bid.value : this.bid,
      body: data.body.present ? data.body.value : this.body,
      routing: data.routing.present ? data.routing.value : this.routing,
      read: data.read.present ? data.read.value : this.read,
      starred: data.starred.present ? data.starred.value : this.starred,
      pendingKill: data.pendingKill.present
          ? data.pendingKill.value
          : this.pendingKill,
      lastListedAt: data.lastListedAt.present
          ? data.lastListedAt.value
          : this.lastListedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('type: $type, ')
          ..write('fromCall: $fromCall, ')
          ..write('toCall: $toCall, ')
          ..write('at: $at, ')
          ..write('subject: $subject, ')
          ..write('date: $date, ')
          ..write('size: $size, ')
          ..write('bid: $bid, ')
          ..write('body: $body, ')
          ..write('routing: $routing, ')
          ..write('read: $read, ')
          ..write('starred: $starred, ')
          ..write('pendingKill: $pendingKill, ')
          ..write('lastListedAt: $lastListedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    connectionId,
    bbsNumber,
    type,
    fromCall,
    toCall,
    at,
    subject,
    date,
    size,
    bid,
    body,
    routing,
    read,
    starred,
    pendingKill,
    lastListedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.connectionId == this.connectionId &&
          other.bbsNumber == this.bbsNumber &&
          other.type == this.type &&
          other.fromCall == this.fromCall &&
          other.toCall == this.toCall &&
          other.at == this.at &&
          other.subject == this.subject &&
          other.date == this.date &&
          other.size == this.size &&
          other.bid == this.bid &&
          other.body == this.body &&
          other.routing == this.routing &&
          other.read == this.read &&
          other.starred == this.starred &&
          other.pendingKill == this.pendingKill &&
          other.lastListedAt == this.lastListedAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> connectionId;
  final Value<int> bbsNumber;
  final Value<String> type;
  final Value<String> fromCall;
  final Value<String> toCall;
  final Value<String?> at;
  final Value<String> subject;
  final Value<DateTime> date;
  final Value<int?> size;
  final Value<String?> bid;
  final Value<String?> body;
  final Value<String?> routing;
  final Value<bool> read;
  final Value<bool> starred;
  final Value<bool> pendingKill;
  final Value<DateTime> lastListedAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.bbsNumber = const Value.absent(),
    this.type = const Value.absent(),
    this.fromCall = const Value.absent(),
    this.toCall = const Value.absent(),
    this.at = const Value.absent(),
    this.subject = const Value.absent(),
    this.date = const Value.absent(),
    this.size = const Value.absent(),
    this.bid = const Value.absent(),
    this.body = const Value.absent(),
    this.routing = const Value.absent(),
    this.read = const Value.absent(),
    this.starred = const Value.absent(),
    this.pendingKill = const Value.absent(),
    this.lastListedAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int connectionId,
    required int bbsNumber,
    required String type,
    required String fromCall,
    required String toCall,
    this.at = const Value.absent(),
    required String subject,
    required DateTime date,
    this.size = const Value.absent(),
    this.bid = const Value.absent(),
    this.body = const Value.absent(),
    this.routing = const Value.absent(),
    this.read = const Value.absent(),
    this.starred = const Value.absent(),
    this.pendingKill = const Value.absent(),
    required DateTime lastListedAt,
  }) : connectionId = Value(connectionId),
       bbsNumber = Value(bbsNumber),
       type = Value(type),
       fromCall = Value(fromCall),
       toCall = Value(toCall),
       subject = Value(subject),
       date = Value(date),
       lastListedAt = Value(lastListedAt);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? connectionId,
    Expression<int>? bbsNumber,
    Expression<String>? type,
    Expression<String>? fromCall,
    Expression<String>? toCall,
    Expression<String>? at,
    Expression<String>? subject,
    Expression<DateTime>? date,
    Expression<int>? size,
    Expression<String>? bid,
    Expression<String>? body,
    Expression<String>? routing,
    Expression<bool>? read,
    Expression<bool>? starred,
    Expression<bool>? pendingKill,
    Expression<DateTime>? lastListedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (connectionId != null) 'connection_id': connectionId,
      if (bbsNumber != null) 'bbs_number': bbsNumber,
      if (type != null) 'type': type,
      if (fromCall != null) 'from_call': fromCall,
      if (toCall != null) 'to_call': toCall,
      if (at != null) 'at': at,
      if (subject != null) 'subject': subject,
      if (date != null) 'date': date,
      if (size != null) 'size': size,
      if (bid != null) 'bid': bid,
      if (body != null) 'body': body,
      if (routing != null) 'routing': routing,
      if (read != null) 'read': read,
      if (starred != null) 'starred': starred,
      if (pendingKill != null) 'pending_kill': pendingKill,
      if (lastListedAt != null) 'last_listed_at': lastListedAt,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? connectionId,
    Value<int>? bbsNumber,
    Value<String>? type,
    Value<String>? fromCall,
    Value<String>? toCall,
    Value<String?>? at,
    Value<String>? subject,
    Value<DateTime>? date,
    Value<int?>? size,
    Value<String?>? bid,
    Value<String?>? body,
    Value<String?>? routing,
    Value<bool>? read,
    Value<bool>? starred,
    Value<bool>? pendingKill,
    Value<DateTime>? lastListedAt,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      bbsNumber: bbsNumber ?? this.bbsNumber,
      type: type ?? this.type,
      fromCall: fromCall ?? this.fromCall,
      toCall: toCall ?? this.toCall,
      at: at ?? this.at,
      subject: subject ?? this.subject,
      date: date ?? this.date,
      size: size ?? this.size,
      bid: bid ?? this.bid,
      body: body ?? this.body,
      routing: routing ?? this.routing,
      read: read ?? this.read,
      starred: starred ?? this.starred,
      pendingKill: pendingKill ?? this.pendingKill,
      lastListedAt: lastListedAt ?? this.lastListedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<int>(connectionId.value);
    }
    if (bbsNumber.present) {
      map['bbs_number'] = Variable<int>(bbsNumber.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (fromCall.present) {
      map['from_call'] = Variable<String>(fromCall.value);
    }
    if (toCall.present) {
      map['to_call'] = Variable<String>(toCall.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (bid.present) {
      map['bid'] = Variable<String>(bid.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (routing.present) {
      map['routing'] = Variable<String>(routing.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (pendingKill.present) {
      map['pending_kill'] = Variable<bool>(pendingKill.value);
    }
    if (lastListedAt.present) {
      map['last_listed_at'] = Variable<DateTime>(lastListedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('type: $type, ')
          ..write('fromCall: $fromCall, ')
          ..write('toCall: $toCall, ')
          ..write('at: $at, ')
          ..write('subject: $subject, ')
          ..write('date: $date, ')
          ..write('size: $size, ')
          ..write('bid: $bid, ')
          ..write('body: $body, ')
          ..write('routing: $routing, ')
          ..write('read: $read, ')
          ..write('starred: $starred, ')
          ..write('pendingKill: $pendingKill, ')
          ..write('lastListedAt: $lastListedAt')
          ..write(')'))
        .toString();
  }
}

class $SentListingsTable extends SentListings
    with TableInfo<$SentListingsTable, SentListing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentListingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<int> connectionId = GeneratedColumn<int>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES connections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bbsNumberMeta = const VerificationMeta(
    'bbsNumber',
  );
  @override
  late final GeneratedColumn<int> bbsNumber = GeneratedColumn<int>(
    'bbs_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toCallMeta = const VerificationMeta('toCall');
  @override
  late final GeneratedColumn<String> toCall = GeneratedColumn<String>(
    'to_call',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routingMeta = const VerificationMeta(
    'routing',
  );
  @override
  late final GeneratedColumn<String> routing = GeneratedColumn<String>(
    'routing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bidMeta = const VerificationMeta('bid');
  @override
  late final GeneratedColumn<String> bid = GeneratedColumn<String>(
    'bid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastListedAtMeta = const VerificationMeta(
    'lastListedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastListedAt = GeneratedColumn<DateTime>(
    'last_listed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    connectionId,
    bbsNumber,
    type,
    status,
    toCall,
    at,
    subject,
    date,
    size,
    body,
    routing,
    bid,
    lastListedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sent_listings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentListing> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('bbs_number')) {
      context.handle(
        _bbsNumberMeta,
        bbsNumber.isAcceptableOrUnknown(data['bbs_number']!, _bbsNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_bbsNumberMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('to_call')) {
      context.handle(
        _toCallMeta,
        toCall.isAcceptableOrUnknown(data['to_call']!, _toCallMeta),
      );
    } else if (isInserting) {
      context.missing(_toCallMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('routing')) {
      context.handle(
        _routingMeta,
        routing.isAcceptableOrUnknown(data['routing']!, _routingMeta),
      );
    }
    if (data.containsKey('bid')) {
      context.handle(
        _bidMeta,
        bid.isAcceptableOrUnknown(data['bid']!, _bidMeta),
      );
    }
    if (data.containsKey('last_listed_at')) {
      context.handle(
        _lastListedAtMeta,
        lastListedAt.isAcceptableOrUnknown(
          data['last_listed_at']!,
          _lastListedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastListedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {connectionId, bbsNumber},
  ];
  @override
  SentListing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentListing(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connection_id'],
      )!,
      bbsNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bbs_number'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      toCall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_call'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}at'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      routing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routing'],
      ),
      bid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bid'],
      ),
      lastListedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_listed_at'],
      )!,
    );
  }

  @override
  $SentListingsTable createAlias(String alias) {
    return $SentListingsTable(attachedDatabase, alias);
  }
}

class SentListing extends DataClass implements Insertable<SentListing> {
  final int id;
  final int connectionId;
  final int bbsNumber;

  /// 'personal', 'bulletin' or 'traffic'.
  final String type;

  /// The BBS status letter: N, Y, F, $ or D.
  final String status;
  final String toCall;
  final String? at;
  final String subject;
  final DateTime date;
  final int? size;

  /// Null until opened.
  final String? body;
  final String? routing;
  final String? bid;
  final DateTime lastListedAt;
  const SentListing({
    required this.id,
    required this.connectionId,
    required this.bbsNumber,
    required this.type,
    required this.status,
    required this.toCall,
    this.at,
    required this.subject,
    required this.date,
    this.size,
    this.body,
    this.routing,
    this.bid,
    required this.lastListedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['connection_id'] = Variable<int>(connectionId);
    map['bbs_number'] = Variable<int>(bbsNumber);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['to_call'] = Variable<String>(toCall);
    if (!nullToAbsent || at != null) {
      map['at'] = Variable<String>(at);
    }
    map['subject'] = Variable<String>(subject);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || routing != null) {
      map['routing'] = Variable<String>(routing);
    }
    if (!nullToAbsent || bid != null) {
      map['bid'] = Variable<String>(bid);
    }
    map['last_listed_at'] = Variable<DateTime>(lastListedAt);
    return map;
  }

  SentListingsCompanion toCompanion(bool nullToAbsent) {
    return SentListingsCompanion(
      id: Value(id),
      connectionId: Value(connectionId),
      bbsNumber: Value(bbsNumber),
      type: Value(type),
      status: Value(status),
      toCall: Value(toCall),
      at: at == null && nullToAbsent ? const Value.absent() : Value(at),
      subject: Value(subject),
      date: Value(date),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      routing: routing == null && nullToAbsent
          ? const Value.absent()
          : Value(routing),
      bid: bid == null && nullToAbsent ? const Value.absent() : Value(bid),
      lastListedAt: Value(lastListedAt),
    );
  }

  factory SentListing.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentListing(
      id: serializer.fromJson<int>(json['id']),
      connectionId: serializer.fromJson<int>(json['connectionId']),
      bbsNumber: serializer.fromJson<int>(json['bbsNumber']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      toCall: serializer.fromJson<String>(json['toCall']),
      at: serializer.fromJson<String?>(json['at']),
      subject: serializer.fromJson<String>(json['subject']),
      date: serializer.fromJson<DateTime>(json['date']),
      size: serializer.fromJson<int?>(json['size']),
      body: serializer.fromJson<String?>(json['body']),
      routing: serializer.fromJson<String?>(json['routing']),
      bid: serializer.fromJson<String?>(json['bid']),
      lastListedAt: serializer.fromJson<DateTime>(json['lastListedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'connectionId': serializer.toJson<int>(connectionId),
      'bbsNumber': serializer.toJson<int>(bbsNumber),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'toCall': serializer.toJson<String>(toCall),
      'at': serializer.toJson<String?>(at),
      'subject': serializer.toJson<String>(subject),
      'date': serializer.toJson<DateTime>(date),
      'size': serializer.toJson<int?>(size),
      'body': serializer.toJson<String?>(body),
      'routing': serializer.toJson<String?>(routing),
      'bid': serializer.toJson<String?>(bid),
      'lastListedAt': serializer.toJson<DateTime>(lastListedAt),
    };
  }

  SentListing copyWith({
    int? id,
    int? connectionId,
    int? bbsNumber,
    String? type,
    String? status,
    String? toCall,
    Value<String?> at = const Value.absent(),
    String? subject,
    DateTime? date,
    Value<int?> size = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<String?> routing = const Value.absent(),
    Value<String?> bid = const Value.absent(),
    DateTime? lastListedAt,
  }) => SentListing(
    id: id ?? this.id,
    connectionId: connectionId ?? this.connectionId,
    bbsNumber: bbsNumber ?? this.bbsNumber,
    type: type ?? this.type,
    status: status ?? this.status,
    toCall: toCall ?? this.toCall,
    at: at.present ? at.value : this.at,
    subject: subject ?? this.subject,
    date: date ?? this.date,
    size: size.present ? size.value : this.size,
    body: body.present ? body.value : this.body,
    routing: routing.present ? routing.value : this.routing,
    bid: bid.present ? bid.value : this.bid,
    lastListedAt: lastListedAt ?? this.lastListedAt,
  );
  SentListing copyWithCompanion(SentListingsCompanion data) {
    return SentListing(
      id: data.id.present ? data.id.value : this.id,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      bbsNumber: data.bbsNumber.present ? data.bbsNumber.value : this.bbsNumber,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      toCall: data.toCall.present ? data.toCall.value : this.toCall,
      at: data.at.present ? data.at.value : this.at,
      subject: data.subject.present ? data.subject.value : this.subject,
      date: data.date.present ? data.date.value : this.date,
      size: data.size.present ? data.size.value : this.size,
      body: data.body.present ? data.body.value : this.body,
      routing: data.routing.present ? data.routing.value : this.routing,
      bid: data.bid.present ? data.bid.value : this.bid,
      lastListedAt: data.lastListedAt.present
          ? data.lastListedAt.value
          : this.lastListedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentListing(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('toCall: $toCall, ')
          ..write('at: $at, ')
          ..write('subject: $subject, ')
          ..write('date: $date, ')
          ..write('size: $size, ')
          ..write('body: $body, ')
          ..write('routing: $routing, ')
          ..write('bid: $bid, ')
          ..write('lastListedAt: $lastListedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    connectionId,
    bbsNumber,
    type,
    status,
    toCall,
    at,
    subject,
    date,
    size,
    body,
    routing,
    bid,
    lastListedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentListing &&
          other.id == this.id &&
          other.connectionId == this.connectionId &&
          other.bbsNumber == this.bbsNumber &&
          other.type == this.type &&
          other.status == this.status &&
          other.toCall == this.toCall &&
          other.at == this.at &&
          other.subject == this.subject &&
          other.date == this.date &&
          other.size == this.size &&
          other.body == this.body &&
          other.routing == this.routing &&
          other.bid == this.bid &&
          other.lastListedAt == this.lastListedAt);
}

class SentListingsCompanion extends UpdateCompanion<SentListing> {
  final Value<int> id;
  final Value<int> connectionId;
  final Value<int> bbsNumber;
  final Value<String> type;
  final Value<String> status;
  final Value<String> toCall;
  final Value<String?> at;
  final Value<String> subject;
  final Value<DateTime> date;
  final Value<int?> size;
  final Value<String?> body;
  final Value<String?> routing;
  final Value<String?> bid;
  final Value<DateTime> lastListedAt;
  const SentListingsCompanion({
    this.id = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.bbsNumber = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.toCall = const Value.absent(),
    this.at = const Value.absent(),
    this.subject = const Value.absent(),
    this.date = const Value.absent(),
    this.size = const Value.absent(),
    this.body = const Value.absent(),
    this.routing = const Value.absent(),
    this.bid = const Value.absent(),
    this.lastListedAt = const Value.absent(),
  });
  SentListingsCompanion.insert({
    this.id = const Value.absent(),
    required int connectionId,
    required int bbsNumber,
    required String type,
    required String status,
    required String toCall,
    this.at = const Value.absent(),
    required String subject,
    required DateTime date,
    this.size = const Value.absent(),
    this.body = const Value.absent(),
    this.routing = const Value.absent(),
    this.bid = const Value.absent(),
    required DateTime lastListedAt,
  }) : connectionId = Value(connectionId),
       bbsNumber = Value(bbsNumber),
       type = Value(type),
       status = Value(status),
       toCall = Value(toCall),
       subject = Value(subject),
       date = Value(date),
       lastListedAt = Value(lastListedAt);
  static Insertable<SentListing> custom({
    Expression<int>? id,
    Expression<int>? connectionId,
    Expression<int>? bbsNumber,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? toCall,
    Expression<String>? at,
    Expression<String>? subject,
    Expression<DateTime>? date,
    Expression<int>? size,
    Expression<String>? body,
    Expression<String>? routing,
    Expression<String>? bid,
    Expression<DateTime>? lastListedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (connectionId != null) 'connection_id': connectionId,
      if (bbsNumber != null) 'bbs_number': bbsNumber,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (toCall != null) 'to_call': toCall,
      if (at != null) 'at': at,
      if (subject != null) 'subject': subject,
      if (date != null) 'date': date,
      if (size != null) 'size': size,
      if (body != null) 'body': body,
      if (routing != null) 'routing': routing,
      if (bid != null) 'bid': bid,
      if (lastListedAt != null) 'last_listed_at': lastListedAt,
    });
  }

  SentListingsCompanion copyWith({
    Value<int>? id,
    Value<int>? connectionId,
    Value<int>? bbsNumber,
    Value<String>? type,
    Value<String>? status,
    Value<String>? toCall,
    Value<String?>? at,
    Value<String>? subject,
    Value<DateTime>? date,
    Value<int?>? size,
    Value<String?>? body,
    Value<String?>? routing,
    Value<String?>? bid,
    Value<DateTime>? lastListedAt,
  }) {
    return SentListingsCompanion(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      bbsNumber: bbsNumber ?? this.bbsNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      toCall: toCall ?? this.toCall,
      at: at ?? this.at,
      subject: subject ?? this.subject,
      date: date ?? this.date,
      size: size ?? this.size,
      body: body ?? this.body,
      routing: routing ?? this.routing,
      bid: bid ?? this.bid,
      lastListedAt: lastListedAt ?? this.lastListedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<int>(connectionId.value);
    }
    if (bbsNumber.present) {
      map['bbs_number'] = Variable<int>(bbsNumber.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (toCall.present) {
      map['to_call'] = Variable<String>(toCall.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (routing.present) {
      map['routing'] = Variable<String>(routing.value);
    }
    if (bid.present) {
      map['bid'] = Variable<String>(bid.value);
    }
    if (lastListedAt.present) {
      map['last_listed_at'] = Variable<DateTime>(lastListedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentListingsCompanion(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('toCall: $toCall, ')
          ..write('at: $at, ')
          ..write('subject: $subject, ')
          ..write('date: $date, ')
          ..write('size: $size, ')
          ..write('body: $body, ')
          ..write('routing: $routing, ')
          ..write('bid: $bid, ')
          ..write('lastListedAt: $lastListedAt')
          ..write(')'))
        .toString();
  }
}

class $OutgoingTable extends Outgoing
    with TableInfo<$OutgoingTable, OutgoingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutgoingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<int> connectionId = GeneratedColumn<int>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES connections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bidMeta = const VerificationMeta('bid');
  @override
  late final GeneratedColumn<String> bid = GeneratedColumn<String>(
    'bid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    connectionId,
    type,
    subject,
    body,
    bid,
    createdAt,
    sentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outgoing';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutgoingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('bid')) {
      context.handle(
        _bidMeta,
        bid.isAcceptableOrUnknown(data['bid']!, _bidMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutgoingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutgoingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connection_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      bid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bid'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      ),
    );
  }

  @override
  $OutgoingTable createAlias(String alias) {
    return $OutgoingTable(attachedDatabase, alias);
  }
}

class OutgoingData extends DataClass implements Insertable<OutgoingData> {
  final int id;
  final int connectionId;

  /// 'personal' or 'bulletin'.
  final String type;
  final String subject;
  final String body;

  /// Bulletins only: our own bulletin ID, if we chose one.
  final String? bid;
  final DateTime createdAt;

  /// Set when the last recipient has been sent; until then it is in the outbox.
  final DateTime? sentAt;
  const OutgoingData({
    required this.id,
    required this.connectionId,
    required this.type,
    required this.subject,
    required this.body,
    this.bid,
    required this.createdAt,
    this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['connection_id'] = Variable<int>(connectionId);
    map['type'] = Variable<String>(type);
    map['subject'] = Variable<String>(subject);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || bid != null) {
      map['bid'] = Variable<String>(bid);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    return map;
  }

  OutgoingCompanion toCompanion(bool nullToAbsent) {
    return OutgoingCompanion(
      id: Value(id),
      connectionId: Value(connectionId),
      type: Value(type),
      subject: Value(subject),
      body: Value(body),
      bid: bid == null && nullToAbsent ? const Value.absent() : Value(bid),
      createdAt: Value(createdAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
    );
  }

  factory OutgoingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutgoingData(
      id: serializer.fromJson<int>(json['id']),
      connectionId: serializer.fromJson<int>(json['connectionId']),
      type: serializer.fromJson<String>(json['type']),
      subject: serializer.fromJson<String>(json['subject']),
      body: serializer.fromJson<String>(json['body']),
      bid: serializer.fromJson<String?>(json['bid']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'connectionId': serializer.toJson<int>(connectionId),
      'type': serializer.toJson<String>(type),
      'subject': serializer.toJson<String>(subject),
      'body': serializer.toJson<String>(body),
      'bid': serializer.toJson<String?>(bid),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
    };
  }

  OutgoingData copyWith({
    int? id,
    int? connectionId,
    String? type,
    String? subject,
    String? body,
    Value<String?> bid = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> sentAt = const Value.absent(),
  }) => OutgoingData(
    id: id ?? this.id,
    connectionId: connectionId ?? this.connectionId,
    type: type ?? this.type,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    bid: bid.present ? bid.value : this.bid,
    createdAt: createdAt ?? this.createdAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
  );
  OutgoingData copyWithCompanion(OutgoingCompanion data) {
    return OutgoingData(
      id: data.id.present ? data.id.value : this.id,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      type: data.type.present ? data.type.value : this.type,
      subject: data.subject.present ? data.subject.value : this.subject,
      body: data.body.present ? data.body.value : this.body,
      bid: data.bid.present ? data.bid.value : this.bid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingData(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('type: $type, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('bid: $bid, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    connectionId,
    type,
    subject,
    body,
    bid,
    createdAt,
    sentAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutgoingData &&
          other.id == this.id &&
          other.connectionId == this.connectionId &&
          other.type == this.type &&
          other.subject == this.subject &&
          other.body == this.body &&
          other.bid == this.bid &&
          other.createdAt == this.createdAt &&
          other.sentAt == this.sentAt);
}

class OutgoingCompanion extends UpdateCompanion<OutgoingData> {
  final Value<int> id;
  final Value<int> connectionId;
  final Value<String> type;
  final Value<String> subject;
  final Value<String> body;
  final Value<String?> bid;
  final Value<DateTime> createdAt;
  final Value<DateTime?> sentAt;
  const OutgoingCompanion({
    this.id = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.type = const Value.absent(),
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.bid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sentAt = const Value.absent(),
  });
  OutgoingCompanion.insert({
    this.id = const Value.absent(),
    required int connectionId,
    required String type,
    required String subject,
    required String body,
    this.bid = const Value.absent(),
    required DateTime createdAt,
    this.sentAt = const Value.absent(),
  }) : connectionId = Value(connectionId),
       type = Value(type),
       subject = Value(subject),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<OutgoingData> custom({
    Expression<int>? id,
    Expression<int>? connectionId,
    Expression<String>? type,
    Expression<String>? subject,
    Expression<String>? body,
    Expression<String>? bid,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? sentAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (connectionId != null) 'connection_id': connectionId,
      if (type != null) 'type': type,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (bid != null) 'bid': bid,
      if (createdAt != null) 'created_at': createdAt,
      if (sentAt != null) 'sent_at': sentAt,
    });
  }

  OutgoingCompanion copyWith({
    Value<int>? id,
    Value<int>? connectionId,
    Value<String>? type,
    Value<String>? subject,
    Value<String>? body,
    Value<String?>? bid,
    Value<DateTime>? createdAt,
    Value<DateTime?>? sentAt,
  }) {
    return OutgoingCompanion(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      bid: bid ?? this.bid,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<int>(connectionId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (bid.present) {
      map['bid'] = Variable<String>(bid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingCompanion(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('type: $type, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('bid: $bid, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }
}

class $OutgoingRecipientsTable extends OutgoingRecipients
    with TableInfo<$OutgoingRecipientsTable, OutgoingRecipient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutgoingRecipientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _outgoingIdMeta = const VerificationMeta(
    'outgoingId',
  );
  @override
  late final GeneratedColumn<int> outgoingId = GeneratedColumn<int>(
    'outgoing_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES outgoing (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _bbsNumberMeta = const VerificationMeta(
    'bbsNumber',
  );
  @override
  late final GeneratedColumn<int> bbsNumber = GeneratedColumn<int>(
    'bbs_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bbsBidMeta = const VerificationMeta('bbsBid');
  @override
  late final GeneratedColumn<String> bbsBid = GeneratedColumn<String>(
    'bbs_bid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _knownTopMeta = const VerificationMeta(
    'knownTop',
  );
  @override
  late final GeneratedColumn<int> knownTop = GeneratedColumn<int>(
    'known_top',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    outgoingId,
    address,
    state,
    bbsNumber,
    bbsBid,
    knownTop,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outgoing_recipients';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutgoingRecipient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('outgoing_id')) {
      context.handle(
        _outgoingIdMeta,
        outgoingId.isAcceptableOrUnknown(data['outgoing_id']!, _outgoingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_outgoingIdMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('bbs_number')) {
      context.handle(
        _bbsNumberMeta,
        bbsNumber.isAcceptableOrUnknown(data['bbs_number']!, _bbsNumberMeta),
      );
    }
    if (data.containsKey('bbs_bid')) {
      context.handle(
        _bbsBidMeta,
        bbsBid.isAcceptableOrUnknown(data['bbs_bid']!, _bbsBidMeta),
      );
    }
    if (data.containsKey('known_top')) {
      context.handle(
        _knownTopMeta,
        knownTop.isAcceptableOrUnknown(data['known_top']!, _knownTopMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutgoingRecipient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutgoingRecipient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      outgoingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outgoing_id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      bbsNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bbs_number'],
      ),
      bbsBid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bbs_bid'],
      ),
      knownTop: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}known_top'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $OutgoingRecipientsTable createAlias(String alias) {
    return $OutgoingRecipientsTable(attachedDatabase, alias);
  }
}

class OutgoingRecipient extends DataClass
    implements Insertable<OutgoingRecipient> {
  final int id;
  final int outgoingId;

  /// As typed (or resolved): CALL@BBS.ROUTE, or CATEGORY@AREA for bulletins.
  final String address;

  /// 'queued', 'sending' (tried, not yet confirmed; sent again with the same
  /// bbsBid, which the BBS refuses if it already has it), 'sent', 'held'
  /// (waiting, with a reason) or 'failed'.
  final String state;
  final int? bbsNumber;
  final String? bbsBid;

  /// The highest message number the app knew on this connection when this
  /// copy was first tried. On a BBS that can't refuse a second copy, only a
  /// higher number can be that try's copy.
  final int? knownTop;

  /// Plain words: why it failed or is held, or what the BBS noted.
  final String? note;
  const OutgoingRecipient({
    required this.id,
    required this.outgoingId,
    required this.address,
    required this.state,
    this.bbsNumber,
    this.bbsBid,
    this.knownTop,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['outgoing_id'] = Variable<int>(outgoingId);
    map['address'] = Variable<String>(address);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || bbsNumber != null) {
      map['bbs_number'] = Variable<int>(bbsNumber);
    }
    if (!nullToAbsent || bbsBid != null) {
      map['bbs_bid'] = Variable<String>(bbsBid);
    }
    if (!nullToAbsent || knownTop != null) {
      map['known_top'] = Variable<int>(knownTop);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  OutgoingRecipientsCompanion toCompanion(bool nullToAbsent) {
    return OutgoingRecipientsCompanion(
      id: Value(id),
      outgoingId: Value(outgoingId),
      address: Value(address),
      state: Value(state),
      bbsNumber: bbsNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(bbsNumber),
      bbsBid: bbsBid == null && nullToAbsent
          ? const Value.absent()
          : Value(bbsBid),
      knownTop: knownTop == null && nullToAbsent
          ? const Value.absent()
          : Value(knownTop),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory OutgoingRecipient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutgoingRecipient(
      id: serializer.fromJson<int>(json['id']),
      outgoingId: serializer.fromJson<int>(json['outgoingId']),
      address: serializer.fromJson<String>(json['address']),
      state: serializer.fromJson<String>(json['state']),
      bbsNumber: serializer.fromJson<int?>(json['bbsNumber']),
      bbsBid: serializer.fromJson<String?>(json['bbsBid']),
      knownTop: serializer.fromJson<int?>(json['knownTop']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'outgoingId': serializer.toJson<int>(outgoingId),
      'address': serializer.toJson<String>(address),
      'state': serializer.toJson<String>(state),
      'bbsNumber': serializer.toJson<int?>(bbsNumber),
      'bbsBid': serializer.toJson<String?>(bbsBid),
      'knownTop': serializer.toJson<int?>(knownTop),
      'note': serializer.toJson<String?>(note),
    };
  }

  OutgoingRecipient copyWith({
    int? id,
    int? outgoingId,
    String? address,
    String? state,
    Value<int?> bbsNumber = const Value.absent(),
    Value<String?> bbsBid = const Value.absent(),
    Value<int?> knownTop = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => OutgoingRecipient(
    id: id ?? this.id,
    outgoingId: outgoingId ?? this.outgoingId,
    address: address ?? this.address,
    state: state ?? this.state,
    bbsNumber: bbsNumber.present ? bbsNumber.value : this.bbsNumber,
    bbsBid: bbsBid.present ? bbsBid.value : this.bbsBid,
    knownTop: knownTop.present ? knownTop.value : this.knownTop,
    note: note.present ? note.value : this.note,
  );
  OutgoingRecipient copyWithCompanion(OutgoingRecipientsCompanion data) {
    return OutgoingRecipient(
      id: data.id.present ? data.id.value : this.id,
      outgoingId: data.outgoingId.present
          ? data.outgoingId.value
          : this.outgoingId,
      address: data.address.present ? data.address.value : this.address,
      state: data.state.present ? data.state.value : this.state,
      bbsNumber: data.bbsNumber.present ? data.bbsNumber.value : this.bbsNumber,
      bbsBid: data.bbsBid.present ? data.bbsBid.value : this.bbsBid,
      knownTop: data.knownTop.present ? data.knownTop.value : this.knownTop,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingRecipient(')
          ..write('id: $id, ')
          ..write('outgoingId: $outgoingId, ')
          ..write('address: $address, ')
          ..write('state: $state, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('bbsBid: $bbsBid, ')
          ..write('knownTop: $knownTop, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    outgoingId,
    address,
    state,
    bbsNumber,
    bbsBid,
    knownTop,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutgoingRecipient &&
          other.id == this.id &&
          other.outgoingId == this.outgoingId &&
          other.address == this.address &&
          other.state == this.state &&
          other.bbsNumber == this.bbsNumber &&
          other.bbsBid == this.bbsBid &&
          other.knownTop == this.knownTop &&
          other.note == this.note);
}

class OutgoingRecipientsCompanion extends UpdateCompanion<OutgoingRecipient> {
  final Value<int> id;
  final Value<int> outgoingId;
  final Value<String> address;
  final Value<String> state;
  final Value<int?> bbsNumber;
  final Value<String?> bbsBid;
  final Value<int?> knownTop;
  final Value<String?> note;
  const OutgoingRecipientsCompanion({
    this.id = const Value.absent(),
    this.outgoingId = const Value.absent(),
    this.address = const Value.absent(),
    this.state = const Value.absent(),
    this.bbsNumber = const Value.absent(),
    this.bbsBid = const Value.absent(),
    this.knownTop = const Value.absent(),
    this.note = const Value.absent(),
  });
  OutgoingRecipientsCompanion.insert({
    this.id = const Value.absent(),
    required int outgoingId,
    required String address,
    this.state = const Value.absent(),
    this.bbsNumber = const Value.absent(),
    this.bbsBid = const Value.absent(),
    this.knownTop = const Value.absent(),
    this.note = const Value.absent(),
  }) : outgoingId = Value(outgoingId),
       address = Value(address);
  static Insertable<OutgoingRecipient> custom({
    Expression<int>? id,
    Expression<int>? outgoingId,
    Expression<String>? address,
    Expression<String>? state,
    Expression<int>? bbsNumber,
    Expression<String>? bbsBid,
    Expression<int>? knownTop,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (outgoingId != null) 'outgoing_id': outgoingId,
      if (address != null) 'address': address,
      if (state != null) 'state': state,
      if (bbsNumber != null) 'bbs_number': bbsNumber,
      if (bbsBid != null) 'bbs_bid': bbsBid,
      if (knownTop != null) 'known_top': knownTop,
      if (note != null) 'note': note,
    });
  }

  OutgoingRecipientsCompanion copyWith({
    Value<int>? id,
    Value<int>? outgoingId,
    Value<String>? address,
    Value<String>? state,
    Value<int?>? bbsNumber,
    Value<String?>? bbsBid,
    Value<int?>? knownTop,
    Value<String?>? note,
  }) {
    return OutgoingRecipientsCompanion(
      id: id ?? this.id,
      outgoingId: outgoingId ?? this.outgoingId,
      address: address ?? this.address,
      state: state ?? this.state,
      bbsNumber: bbsNumber ?? this.bbsNumber,
      bbsBid: bbsBid ?? this.bbsBid,
      knownTop: knownTop ?? this.knownTop,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (outgoingId.present) {
      map['outgoing_id'] = Variable<int>(outgoingId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (bbsNumber.present) {
      map['bbs_number'] = Variable<int>(bbsNumber.value);
    }
    if (bbsBid.present) {
      map['bbs_bid'] = Variable<String>(bbsBid.value);
    }
    if (knownTop.present) {
      map['known_top'] = Variable<int>(knownTop.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingRecipientsCompanion(')
          ..write('id: $id, ')
          ..write('outgoingId: $outgoingId, ')
          ..write('address: $address, ')
          ..write('state: $state, ')
          ..write('bbsNumber: $bbsNumber, ')
          ..write('bbsBid: $bbsBid, ')
          ..write('knownTop: $knownTop, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _callsignMeta = const VerificationMeta(
    'callsign',
  );
  @override
  late final GeneratedColumn<String> callsign = GeneratedColumn<String>(
    'callsign',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeBbsMeta = const VerificationMeta(
    'homeBbs',
  );
  @override
  late final GeneratedColumn<String> homeBbs = GeneratedColumn<String>(
    'home_bbs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    callsign,
    name,
    homeBbs,
    notes,
    source,
    edited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('callsign')) {
      context.handle(
        _callsignMeta,
        callsign.isAcceptableOrUnknown(data['callsign']!, _callsignMeta),
      );
    } else if (isInserting) {
      context.missing(_callsignMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('home_bbs')) {
      context.handle(
        _homeBbsMeta,
        homeBbs.isAcceptableOrUnknown(data['home_bbs']!, _homeBbsMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {callsign};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      callsign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}callsign'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      homeBbs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_bbs'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String callsign;
  final String? name;

  /// Full hierarchical address of their home BBS.
  final String? homeBbs;
  final String? notes;

  /// 'typed', 'mail' or 'whitepages'.
  final String source;

  /// Edited by the user: never overwritten automatically.
  final bool edited;
  const Contact({
    required this.callsign,
    this.name,
    this.homeBbs,
    this.notes,
    required this.source,
    required this.edited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['callsign'] = Variable<String>(callsign);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || homeBbs != null) {
      map['home_bbs'] = Variable<String>(homeBbs);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['source'] = Variable<String>(source);
    map['edited'] = Variable<bool>(edited);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      callsign: Value(callsign),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      homeBbs: homeBbs == null && nullToAbsent
          ? const Value.absent()
          : Value(homeBbs),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      source: Value(source),
      edited: Value(edited),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      callsign: serializer.fromJson<String>(json['callsign']),
      name: serializer.fromJson<String?>(json['name']),
      homeBbs: serializer.fromJson<String?>(json['homeBbs']),
      notes: serializer.fromJson<String?>(json['notes']),
      source: serializer.fromJson<String>(json['source']),
      edited: serializer.fromJson<bool>(json['edited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'callsign': serializer.toJson<String>(callsign),
      'name': serializer.toJson<String?>(name),
      'homeBbs': serializer.toJson<String?>(homeBbs),
      'notes': serializer.toJson<String?>(notes),
      'source': serializer.toJson<String>(source),
      'edited': serializer.toJson<bool>(edited),
    };
  }

  Contact copyWith({
    String? callsign,
    Value<String?> name = const Value.absent(),
    Value<String?> homeBbs = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? source,
    bool? edited,
  }) => Contact(
    callsign: callsign ?? this.callsign,
    name: name.present ? name.value : this.name,
    homeBbs: homeBbs.present ? homeBbs.value : this.homeBbs,
    notes: notes.present ? notes.value : this.notes,
    source: source ?? this.source,
    edited: edited ?? this.edited,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      callsign: data.callsign.present ? data.callsign.value : this.callsign,
      name: data.name.present ? data.name.value : this.name,
      homeBbs: data.homeBbs.present ? data.homeBbs.value : this.homeBbs,
      notes: data.notes.present ? data.notes.value : this.notes,
      source: data.source.present ? data.source.value : this.source,
      edited: data.edited.present ? data.edited.value : this.edited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('callsign: $callsign, ')
          ..write('name: $name, ')
          ..write('homeBbs: $homeBbs, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(callsign, name, homeBbs, notes, source, edited);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.callsign == this.callsign &&
          other.name == this.name &&
          other.homeBbs == this.homeBbs &&
          other.notes == this.notes &&
          other.source == this.source &&
          other.edited == this.edited);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> callsign;
  final Value<String?> name;
  final Value<String?> homeBbs;
  final Value<String?> notes;
  final Value<String> source;
  final Value<bool> edited;
  final Value<int> rowid;
  const ContactsCompanion({
    this.callsign = const Value.absent(),
    this.name = const Value.absent(),
    this.homeBbs = const Value.absent(),
    this.notes = const Value.absent(),
    this.source = const Value.absent(),
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String callsign,
    this.name = const Value.absent(),
    this.homeBbs = const Value.absent(),
    this.notes = const Value.absent(),
    required String source,
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : callsign = Value(callsign),
       source = Value(source);
  static Insertable<Contact> custom({
    Expression<String>? callsign,
    Expression<String>? name,
    Expression<String>? homeBbs,
    Expression<String>? notes,
    Expression<String>? source,
    Expression<bool>? edited,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (callsign != null) 'callsign': callsign,
      if (name != null) 'name': name,
      if (homeBbs != null) 'home_bbs': homeBbs,
      if (notes != null) 'notes': notes,
      if (source != null) 'source': source,
      if (edited != null) 'edited': edited,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? callsign,
    Value<String?>? name,
    Value<String?>? homeBbs,
    Value<String?>? notes,
    Value<String>? source,
    Value<bool>? edited,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      callsign: callsign ?? this.callsign,
      name: name ?? this.name,
      homeBbs: homeBbs ?? this.homeBbs,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      edited: edited ?? this.edited,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (callsign.present) {
      map['callsign'] = Variable<String>(callsign.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (homeBbs.present) {
      map['home_bbs'] = Variable<String>(homeBbs.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('callsign: $callsign, ')
          ..write('name: $name, ')
          ..write('homeBbs: $homeBbs, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('edited: $edited, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubscriptionsTable extends Subscriptions
    with TableInfo<$SubscriptionsTable, Subscription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, category, area];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subscription> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subscription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subscription(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      ),
    );
  }

  @override
  $SubscriptionsTable createAlias(String alias) {
    return $SubscriptionsTable(attachedDatabase, alias);
  }
}

class Subscription extends DataClass implements Insertable<Subscription> {
  final int id;
  final String? category;
  final String? area;
  const Subscription({required this.id, this.category, this.area});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || area != null) {
      map['area'] = Variable<String>(area);
    }
    return map;
  }

  SubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionsCompanion(
      id: Value(id),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      area: area == null && nullToAbsent ? const Value.absent() : Value(area),
    );
  }

  factory Subscription.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subscription(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String?>(json['category']),
      area: serializer.fromJson<String?>(json['area']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String?>(category),
      'area': serializer.toJson<String?>(area),
    };
  }

  Subscription copyWith({
    int? id,
    Value<String?> category = const Value.absent(),
    Value<String?> area = const Value.absent(),
  }) => Subscription(
    id: id ?? this.id,
    category: category.present ? category.value : this.category,
    area: area.present ? area.value : this.area,
  );
  Subscription copyWithCompanion(SubscriptionsCompanion data) {
    return Subscription(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      area: data.area.present ? data.area.value : this.area,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subscription(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('area: $area')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, category, area);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subscription &&
          other.id == this.id &&
          other.category == this.category &&
          other.area == this.area);
}

class SubscriptionsCompanion extends UpdateCompanion<Subscription> {
  final Value<int> id;
  final Value<String?> category;
  final Value<String?> area;
  const SubscriptionsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.area = const Value.absent(),
  });
  SubscriptionsCompanion.insert({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.area = const Value.absent(),
  });
  static Insertable<Subscription> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<String>? area,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (area != null) 'area': area,
    });
  }

  SubscriptionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? category,
    Value<String?>? area,
  }) {
    return SubscriptionsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      area: area ?? this.area,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('area: $area')
          ..write(')'))
        .toString();
  }
}

abstract class _$MailStore extends GeneratedDatabase {
  _$MailStore(QueryExecutor e) : super(e);
  $MailStoreManager get managers => $MailStoreManager(this);
  late final $IdentitiesTable identities = $IdentitiesTable(this);
  late final $ConnectionsTable connections = $ConnectionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $SentListingsTable sentListings = $SentListingsTable(this);
  late final $OutgoingTable outgoing = $OutgoingTable(this);
  late final $OutgoingRecipientsTable outgoingRecipients =
      $OutgoingRecipientsTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $SubscriptionsTable subscriptions = $SubscriptionsTable(this);
  late final Index messagesBid = Index(
    'messages_bid',
    'CREATE INDEX messages_bid ON messages (bid)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    identities,
    connections,
    messages,
    sentListings,
    outgoing,
    outgoingRecipients,
    contacts,
    subscriptions,
    messagesBid,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'connections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'connections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sent_listings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'connections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('outgoing', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'outgoing',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('outgoing_recipients', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$IdentitiesTableCreateCompanionBuilder = IdentitiesCompanion Function({
  Value<int> id,
  required String callsign,
  required String name,
  required String homeBbs,
});
typedef $$IdentitiesTableUpdateCompanionBuilder = IdentitiesCompanion Function({
  Value<int> id,
  Value<String> callsign,
  Value<String> name,
  Value<String> homeBbs,
});

class $$IdentitiesTableFilterComposer
    extends Composer<_$MailStore, $IdentitiesTable> {
  $$IdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeBbs => $composableBuilder(
    column: $table.homeBbs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentitiesTableOrderingComposer
    extends Composer<_$MailStore, $IdentitiesTable> {
  $$IdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeBbs => $composableBuilder(
    column: $table.homeBbs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentitiesTableAnnotationComposer
    extends Composer<_$MailStore, $IdentitiesTable> {
  $$IdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get callsign =>
      $composableBuilder(column: $table.callsign, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get homeBbs =>
      $composableBuilder(column: $table.homeBbs, builder: (column) => column);
}

class $$IdentitiesTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $IdentitiesTable,
          Identity,
          $$IdentitiesTableFilterComposer,
          $$IdentitiesTableOrderingComposer,
          $$IdentitiesTableAnnotationComposer,
          $$IdentitiesTableCreateCompanionBuilder,
          $$IdentitiesTableUpdateCompanionBuilder,
          (Identity, BaseReferences<_$MailStore, $IdentitiesTable, Identity>),
          Identity,
          PrefetchHooks Function()
        > {
  $$IdentitiesTableTableManager(_$MailStore db, $IdentitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> callsign = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> homeBbs = const Value.absent(),
              }) => IdentitiesCompanion(
                id: id,
                callsign: callsign,
                name: name,
                homeBbs: homeBbs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String callsign,
                required String name,
                required String homeBbs,
              }) => IdentitiesCompanion.insert(
                id: id,
                callsign: callsign,
                name: name,
                homeBbs: homeBbs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdentitiesTable, Identity>(table),
                  BaseReferences<_$MailStore, $IdentitiesTable, Identity>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $IdentitiesTable,
      Identity,
      $$IdentitiesTableFilterComposer,
      $$IdentitiesTableOrderingComposer,
      $$IdentitiesTableAnnotationComposer,
      $$IdentitiesTableCreateCompanionBuilder,
      $$IdentitiesTableUpdateCompanionBuilder,
      (Identity, BaseReferences<_$MailStore, $IdentitiesTable, Identity>),
      Identity,
      PrefetchHooks Function()
    >;
typedef $$ConnectionsTableCreateCompanionBuilder =
    ConnectionsCompanion Function({
      Value<int> id,
      required String name,
      required String bbsType,
      required String host,
      required int port,
      required String portKind,
      required String loginName,
      Value<String> personalDownload,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastSyncResult,
    });
typedef $$ConnectionsTableUpdateCompanionBuilder =
    ConnectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> bbsType,
      Value<String> host,
      Value<int> port,
      Value<String> portKind,
      Value<String> loginName,
      Value<String> personalDownload,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastSyncResult,
    });

final class $$ConnectionsTableReferences
    extends BaseReferences<_$MailStore, $ConnectionsTable, Connection> {
  $$ConnectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$MailStore db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'connections__id__messages__connection_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.connectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SentListingsTable, List<SentListing>>
  _sentListingsRefsTable(_$MailStore db) => MultiTypedResultKey.fromTable(
    db.sentListings,
    aliasName: 'connections__id__sent_listings__connection_id',
  );

  $$SentListingsTableProcessedTableManager get sentListingsRefs {
    final manager = $$SentListingsTableTableManager(
      $_db,
      $_db.sentListings,
    ).filter((f) => f.connectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sentListingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OutgoingTable, List<OutgoingData>>
  _outgoingRefsTable(_$MailStore db) => MultiTypedResultKey.fromTable(
    db.outgoing,
    aliasName: 'connections__id__outgoing__connection_id',
  );

  $$OutgoingTableProcessedTableManager get outgoingRefs {
    final manager = $$OutgoingTableTableManager(
      $_db,
      $_db.outgoing,
    ).filter((f) => f.connectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_outgoingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConnectionsTableFilterComposer
    extends Composer<_$MailStore, $ConnectionsTable> {
  $$ConnectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bbsType => $composableBuilder(
    column: $table.bbsType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portKind => $composableBuilder(
    column: $table.portKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personalDownload => $composableBuilder(
    column: $table.personalDownload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncResult => $composableBuilder(
    column: $table.lastSyncResult,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sentListingsRefs(
    Expression<bool> Function($$SentListingsTableFilterComposer f) f,
  ) {
    final $$SentListingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sentListings,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SentListingsTableFilterComposer(
            $db: $db,
            $table: $db.sentListings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outgoingRefs(
    Expression<bool> Function($$OutgoingTableFilterComposer f) f,
  ) {
    final $$OutgoingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outgoing,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingTableFilterComposer(
            $db: $db,
            $table: $db.outgoing,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConnectionsTableOrderingComposer
    extends Composer<_$MailStore, $ConnectionsTable> {
  $$ConnectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bbsType => $composableBuilder(
    column: $table.bbsType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portKind => $composableBuilder(
    column: $table.portKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalDownload => $composableBuilder(
    column: $table.personalDownload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncResult => $composableBuilder(
    column: $table.lastSyncResult,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectionsTableAnnotationComposer
    extends Composer<_$MailStore, $ConnectionsTable> {
  $$ConnectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bbsType =>
      $composableBuilder(column: $table.bbsType, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get portKind =>
      $composableBuilder(column: $table.portKind, builder: (column) => column);

  GeneratedColumn<String> get loginName =>
      $composableBuilder(column: $table.loginName, builder: (column) => column);

  GeneratedColumn<String> get personalDownload => $composableBuilder(
    column: $table.personalDownload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncResult => $composableBuilder(
    column: $table.lastSyncResult,
    builder: (column) => column,
  );

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sentListingsRefs<T extends Object>(
    Expression<T> Function($$SentListingsTableAnnotationComposer a) f,
  ) {
    final $$SentListingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sentListings,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SentListingsTableAnnotationComposer(
            $db: $db,
            $table: $db.sentListings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outgoingRefs<T extends Object>(
    Expression<T> Function($$OutgoingTableAnnotationComposer a) f,
  ) {
    final $$OutgoingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outgoing,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingTableAnnotationComposer(
            $db: $db,
            $table: $db.outgoing,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConnectionsTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $ConnectionsTable,
          Connection,
          $$ConnectionsTableFilterComposer,
          $$ConnectionsTableOrderingComposer,
          $$ConnectionsTableAnnotationComposer,
          $$ConnectionsTableCreateCompanionBuilder,
          $$ConnectionsTableUpdateCompanionBuilder,
          (Connection, $$ConnectionsTableReferences),
          Connection,
          PrefetchHooks Function({
            bool messagesRefs,
            bool sentListingsRefs,
            bool outgoingRefs,
          })
        > {
  $$ConnectionsTableTableManager(_$MailStore db, $ConnectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bbsType = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> portKind = const Value.absent(),
                Value<String> loginName = const Value.absent(),
                Value<String> personalDownload = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastSyncResult = const Value.absent(),
              }) => ConnectionsCompanion(
                id: id,
                name: name,
                bbsType: bbsType,
                host: host,
                port: port,
                portKind: portKind,
                loginName: loginName,
                personalDownload: personalDownload,
                lastSyncAt: lastSyncAt,
                lastSyncResult: lastSyncResult,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String bbsType,
                required String host,
                required int port,
                required String portKind,
                required String loginName,
                Value<String> personalDownload = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastSyncResult = const Value.absent(),
              }) => ConnectionsCompanion.insert(
                id: id,
                name: name,
                bbsType: bbsType,
                host: host,
                port: port,
                portKind: portKind,
                loginName: loginName,
                personalDownload: personalDownload,
                lastSyncAt: lastSyncAt,
                lastSyncResult: lastSyncResult,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConnectionsTable, Connection>(table),
                  $$ConnectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                messagesRefs = false,
                sentListingsRefs = false,
                outgoingRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messagesRefs) db.messages,
                    if (sentListingsRefs) db.sentListings,
                    if (outgoingRefs) db.outgoing,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedDataByColumns<
                          Connection,
                          $ConnectionsTable,
                          Message,
                          $MessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ConnectionsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConnectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'connection_id',
                          typedResults: items,
                        ),
                      if (sentListingsRefs)
                        await $_getPrefetchedDataByColumns<
                          Connection,
                          $ConnectionsTable,
                          SentListing,
                          $SentListingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ConnectionsTableReferences
                              ._sentListingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConnectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sentListingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'connection_id',
                          typedResults: items,
                        ),
                      if (outgoingRefs)
                        await $_getPrefetchedDataByColumns<
                          Connection,
                          $ConnectionsTable,
                          OutgoingData,
                          $OutgoingTable
                        >(
                          currentTable: table,
                          referencedTable: $$ConnectionsTableReferences
                              ._outgoingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConnectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).outgoingRefs,
                          currentColumn: 'id',
                          referencedColumn: 'connection_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConnectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $ConnectionsTable,
      Connection,
      $$ConnectionsTableFilterComposer,
      $$ConnectionsTableOrderingComposer,
      $$ConnectionsTableAnnotationComposer,
      $$ConnectionsTableCreateCompanionBuilder,
      $$ConnectionsTableUpdateCompanionBuilder,
      (Connection, $$ConnectionsTableReferences),
      Connection,
      PrefetchHooks Function({
        bool messagesRefs,
        bool sentListingsRefs,
        bool outgoingRefs,
      })
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required int connectionId,
  required int bbsNumber,
  required String type,
  required String fromCall,
  required String toCall,
  Value<String?> at,
  required String subject,
  required DateTime date,
  Value<int?> size,
  Value<String?> bid,
  Value<String?> body,
  Value<String?> routing,
  Value<bool> read,
  Value<bool> starred,
  Value<bool> pendingKill,
  required DateTime lastListedAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> connectionId,
  Value<int> bbsNumber,
  Value<String> type,
  Value<String> fromCall,
  Value<String> toCall,
  Value<String?> at,
  Value<String> subject,
  Value<DateTime> date,
  Value<int?> size,
  Value<String?> bid,
  Value<String?> body,
  Value<String?> routing,
  Value<bool> read,
  Value<bool> starred,
  Value<bool> pendingKill,
  Value<DateTime> lastListedAt,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$MailStore, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConnectionsTable _connectionIdTable(_$MailStore db) =>
      db.connections.createAlias('messages__connection_id__connections__id');

  $$ConnectionsTableProcessedTableManager get connectionId {
    final $_column = $_itemColumn<int>('connection_id')!;

    final manager = $$ConnectionsTableTableManager(
      $_db,
      $_db.connections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_connectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$MailStore, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromCall => $composableBuilder(
    column: $table.fromCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toCall => $composableBuilder(
    column: $table.toCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routing => $composableBuilder(
    column: $table.routing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingKill => $composableBuilder(
    column: $table.pendingKill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConnectionsTableFilterComposer get connectionId {
    final $$ConnectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableFilterComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$MailStore, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromCall => $composableBuilder(
    column: $table.fromCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toCall => $composableBuilder(
    column: $table.toCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routing => $composableBuilder(
    column: $table.routing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingKill => $composableBuilder(
    column: $table.pendingKill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConnectionsTableOrderingComposer get connectionId {
    final $$ConnectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableOrderingComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$MailStore, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bbsNumber =>
      $composableBuilder(column: $table.bbsNumber, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get fromCall =>
      $composableBuilder(column: $table.fromCall, builder: (column) => column);

  GeneratedColumn<String> get toCall =>
      $composableBuilder(column: $table.toCall, builder: (column) => column);

  GeneratedColumn<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get bid =>
      $composableBuilder(column: $table.bid, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get routing =>
      $composableBuilder(column: $table.routing, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get pendingKill => $composableBuilder(
    column: $table.pendingKill,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => column,
  );

  $$ConnectionsTableAnnotationComposer get connectionId {
    final $$ConnectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool connectionId})
        > {
  $$MessagesTableTableManager(_$MailStore db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> connectionId = const Value.absent(),
                Value<int> bbsNumber = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> fromCall = const Value.absent(),
                Value<String> toCall = const Value.absent(),
                Value<String?> at = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<String?> bid = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> routing = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> pendingKill = const Value.absent(),
                Value<DateTime> lastListedAt = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                connectionId: connectionId,
                bbsNumber: bbsNumber,
                type: type,
                fromCall: fromCall,
                toCall: toCall,
                at: at,
                subject: subject,
                date: date,
                size: size,
                bid: bid,
                body: body,
                routing: routing,
                read: read,
                starred: starred,
                pendingKill: pendingKill,
                lastListedAt: lastListedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int connectionId,
                required int bbsNumber,
                required String type,
                required String fromCall,
                required String toCall,
                Value<String?> at = const Value.absent(),
                required String subject,
                required DateTime date,
                Value<int?> size = const Value.absent(),
                Value<String?> bid = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> routing = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> pendingKill = const Value.absent(),
                required DateTime lastListedAt,
              }) => MessagesCompanion.insert(
                id: id,
                connectionId: connectionId,
                bbsNumber: bbsNumber,
                type: type,
                fromCall: fromCall,
                toCall: toCall,
                at: at,
                subject: subject,
                date: date,
                size: size,
                bid: bid,
                body: body,
                routing: routing,
                read: read,
                starred: starred,
                pendingKill: pendingKill,
                lastListedAt: lastListedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({connectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (connectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.connectionId,
                        referencedTable: $$MessagesTableReferences
                            ._connectionIdTable(db),
                        referencedColumn: $$MessagesTableReferences
                            ._connectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool connectionId})
    >;
typedef $$SentListingsTableCreateCompanionBuilder =
    SentListingsCompanion Function({
      Value<int> id,
      required int connectionId,
      required int bbsNumber,
      required String type,
      required String status,
      required String toCall,
      Value<String?> at,
      required String subject,
      required DateTime date,
      Value<int?> size,
      Value<String?> body,
      Value<String?> routing,
      Value<String?> bid,
      required DateTime lastListedAt,
    });
typedef $$SentListingsTableUpdateCompanionBuilder =
    SentListingsCompanion Function({
      Value<int> id,
      Value<int> connectionId,
      Value<int> bbsNumber,
      Value<String> type,
      Value<String> status,
      Value<String> toCall,
      Value<String?> at,
      Value<String> subject,
      Value<DateTime> date,
      Value<int?> size,
      Value<String?> body,
      Value<String?> routing,
      Value<String?> bid,
      Value<DateTime> lastListedAt,
    });

final class $$SentListingsTableReferences
    extends BaseReferences<_$MailStore, $SentListingsTable, SentListing> {
  $$SentListingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConnectionsTable _connectionIdTable(_$MailStore db) => db.connections
      .createAlias('sent_listings__connection_id__connections__id');

  $$ConnectionsTableProcessedTableManager get connectionId {
    final $_column = $_itemColumn<int>('connection_id')!;

    final manager = $$ConnectionsTableTableManager(
      $_db,
      $_db.connections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_connectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SentListingsTableFilterComposer
    extends Composer<_$MailStore, $SentListingsTable> {
  $$SentListingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toCall => $composableBuilder(
    column: $table.toCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routing => $composableBuilder(
    column: $table.routing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConnectionsTableFilterComposer get connectionId {
    final $$ConnectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableFilterComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SentListingsTableOrderingComposer
    extends Composer<_$MailStore, $SentListingsTable> {
  $$SentListingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toCall => $composableBuilder(
    column: $table.toCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routing => $composableBuilder(
    column: $table.routing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConnectionsTableOrderingComposer get connectionId {
    final $$ConnectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableOrderingComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SentListingsTableAnnotationComposer
    extends Composer<_$MailStore, $SentListingsTable> {
  $$SentListingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bbsNumber =>
      $composableBuilder(column: $table.bbsNumber, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get toCall =>
      $composableBuilder(column: $table.toCall, builder: (column) => column);

  GeneratedColumn<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get routing =>
      $composableBuilder(column: $table.routing, builder: (column) => column);

  GeneratedColumn<String> get bid =>
      $composableBuilder(column: $table.bid, builder: (column) => column);

  GeneratedColumn<DateTime> get lastListedAt => $composableBuilder(
    column: $table.lastListedAt,
    builder: (column) => column,
  );

  $$ConnectionsTableAnnotationComposer get connectionId {
    final $$ConnectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SentListingsTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $SentListingsTable,
          SentListing,
          $$SentListingsTableFilterComposer,
          $$SentListingsTableOrderingComposer,
          $$SentListingsTableAnnotationComposer,
          $$SentListingsTableCreateCompanionBuilder,
          $$SentListingsTableUpdateCompanionBuilder,
          (SentListing, $$SentListingsTableReferences),
          SentListing,
          PrefetchHooks Function({bool connectionId})
        > {
  $$SentListingsTableTableManager(_$MailStore db, $SentListingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentListingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentListingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentListingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> connectionId = const Value.absent(),
                Value<int> bbsNumber = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> toCall = const Value.absent(),
                Value<String?> at = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> routing = const Value.absent(),
                Value<String?> bid = const Value.absent(),
                Value<DateTime> lastListedAt = const Value.absent(),
              }) => SentListingsCompanion(
                id: id,
                connectionId: connectionId,
                bbsNumber: bbsNumber,
                type: type,
                status: status,
                toCall: toCall,
                at: at,
                subject: subject,
                date: date,
                size: size,
                body: body,
                routing: routing,
                bid: bid,
                lastListedAt: lastListedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int connectionId,
                required int bbsNumber,
                required String type,
                required String status,
                required String toCall,
                Value<String?> at = const Value.absent(),
                required String subject,
                required DateTime date,
                Value<int?> size = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> routing = const Value.absent(),
                Value<String?> bid = const Value.absent(),
                required DateTime lastListedAt,
              }) => SentListingsCompanion.insert(
                id: id,
                connectionId: connectionId,
                bbsNumber: bbsNumber,
                type: type,
                status: status,
                toCall: toCall,
                at: at,
                subject: subject,
                date: date,
                size: size,
                body: body,
                routing: routing,
                bid: bid,
                lastListedAt: lastListedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SentListingsTable, SentListing>(table),
                  $$SentListingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({connectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (connectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.connectionId,
                        referencedTable: $$SentListingsTableReferences
                            ._connectionIdTable(db),
                        referencedColumn: $$SentListingsTableReferences
                            ._connectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SentListingsTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $SentListingsTable,
      SentListing,
      $$SentListingsTableFilterComposer,
      $$SentListingsTableOrderingComposer,
      $$SentListingsTableAnnotationComposer,
      $$SentListingsTableCreateCompanionBuilder,
      $$SentListingsTableUpdateCompanionBuilder,
      (SentListing, $$SentListingsTableReferences),
      SentListing,
      PrefetchHooks Function({bool connectionId})
    >;
typedef $$OutgoingTableCreateCompanionBuilder = OutgoingCompanion Function({
  Value<int> id,
  required int connectionId,
  required String type,
  required String subject,
  required String body,
  Value<String?> bid,
  required DateTime createdAt,
  Value<DateTime?> sentAt,
});
typedef $$OutgoingTableUpdateCompanionBuilder = OutgoingCompanion Function({
  Value<int> id,
  Value<int> connectionId,
  Value<String> type,
  Value<String> subject,
  Value<String> body,
  Value<String?> bid,
  Value<DateTime> createdAt,
  Value<DateTime?> sentAt,
});

final class $$OutgoingTableReferences
    extends BaseReferences<_$MailStore, $OutgoingTable, OutgoingData> {
  $$OutgoingTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConnectionsTable _connectionIdTable(_$MailStore db) =>
      db.connections.createAlias('outgoing__connection_id__connections__id');

  $$ConnectionsTableProcessedTableManager get connectionId {
    final $_column = $_itemColumn<int>('connection_id')!;

    final manager = $$ConnectionsTableTableManager(
      $_db,
      $_db.connections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_connectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$OutgoingRecipientsTable, List<OutgoingRecipient>>
  _outgoingRecipientsRefsTable(_$MailStore db) => MultiTypedResultKey.fromTable(
    db.outgoingRecipients,
    aliasName: 'outgoing__id__outgoing_recipients__outgoing_id',
  );

  $$OutgoingRecipientsTableProcessedTableManager get outgoingRecipientsRefs {
    final manager = $$OutgoingRecipientsTableTableManager(
      $_db,
      $_db.outgoingRecipients,
    ).filter((f) => f.outgoingId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _outgoingRecipientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OutgoingTableFilterComposer
    extends Composer<_$MailStore, $OutgoingTable> {
  $$OutgoingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConnectionsTableFilterComposer get connectionId {
    final $$ConnectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableFilterComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> outgoingRecipientsRefs(
    Expression<bool> Function($$OutgoingRecipientsTableFilterComposer f) f,
  ) {
    final $$OutgoingRecipientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outgoingRecipients,
      getReferencedColumn: (t) => t.outgoingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingRecipientsTableFilterComposer(
            $db: $db,
            $table: $db.outgoingRecipients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OutgoingTableOrderingComposer
    extends Composer<_$MailStore, $OutgoingTable> {
  $$OutgoingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bid => $composableBuilder(
    column: $table.bid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConnectionsTableOrderingComposer get connectionId {
    final $$ConnectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableOrderingComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutgoingTableAnnotationComposer
    extends Composer<_$MailStore, $OutgoingTable> {
  $$OutgoingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get bid =>
      $composableBuilder(column: $table.bid, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  $$ConnectionsTableAnnotationComposer get connectionId {
    final $$ConnectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.connections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.connections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> outgoingRecipientsRefs<T extends Object>(
    Expression<T> Function($$OutgoingRecipientsTableAnnotationComposer a) f,
  ) {
    final $$OutgoingRecipientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.outgoingRecipients,
          getReferencedColumn: (t) => t.outgoingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$OutgoingRecipientsTableAnnotationComposer(
                $db: $db,
                $table: $db.outgoingRecipients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$OutgoingTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $OutgoingTable,
          OutgoingData,
          $$OutgoingTableFilterComposer,
          $$OutgoingTableOrderingComposer,
          $$OutgoingTableAnnotationComposer,
          $$OutgoingTableCreateCompanionBuilder,
          $$OutgoingTableUpdateCompanionBuilder,
          (OutgoingData, $$OutgoingTableReferences),
          OutgoingData,
          PrefetchHooks Function({
            bool connectionId,
            bool outgoingRecipientsRefs,
          })
        > {
  $$OutgoingTableTableManager(_$MailStore db, $OutgoingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutgoingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutgoingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutgoingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> connectionId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> bid = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
              }) => OutgoingCompanion(
                id: id,
                connectionId: connectionId,
                type: type,
                subject: subject,
                body: body,
                bid: bid,
                createdAt: createdAt,
                sentAt: sentAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int connectionId,
                required String type,
                required String subject,
                required String body,
                Value<String?> bid = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> sentAt = const Value.absent(),
              }) => OutgoingCompanion.insert(
                id: id,
                connectionId: connectionId,
                type: type,
                subject: subject,
                body: body,
                bid: bid,
                createdAt: createdAt,
                sentAt: sentAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutgoingTable, OutgoingData>(table),
                  $$OutgoingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({connectionId = false, outgoingRecipientsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (outgoingRecipientsRefs) db.outgoingRecipients,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (connectionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.connectionId,
                            referencedTable: $$OutgoingTableReferences
                                ._connectionIdTable(db),
                            referencedColumn: $$OutgoingTableReferences
                                ._connectionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (outgoingRecipientsRefs)
                        await $_getPrefetchedDataByColumns<
                          OutgoingData,
                          $OutgoingTable,
                          OutgoingRecipient,
                          $OutgoingRecipientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$OutgoingTableReferences
                              ._outgoingRecipientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OutgoingTableReferences(
                                db,
                                table,
                                p0,
                              ).outgoingRecipientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'outgoing_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$OutgoingTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $OutgoingTable,
      OutgoingData,
      $$OutgoingTableFilterComposer,
      $$OutgoingTableOrderingComposer,
      $$OutgoingTableAnnotationComposer,
      $$OutgoingTableCreateCompanionBuilder,
      $$OutgoingTableUpdateCompanionBuilder,
      (OutgoingData, $$OutgoingTableReferences),
      OutgoingData,
      PrefetchHooks Function({bool connectionId, bool outgoingRecipientsRefs})
    >;
typedef $$OutgoingRecipientsTableCreateCompanionBuilder =
    OutgoingRecipientsCompanion Function({
      Value<int> id,
      required int outgoingId,
      required String address,
      Value<String> state,
      Value<int?> bbsNumber,
      Value<String?> bbsBid,
      Value<int?> knownTop,
      Value<String?> note,
    });
typedef $$OutgoingRecipientsTableUpdateCompanionBuilder =
    OutgoingRecipientsCompanion Function({
      Value<int> id,
      Value<int> outgoingId,
      Value<String> address,
      Value<String> state,
      Value<int?> bbsNumber,
      Value<String?> bbsBid,
      Value<int?> knownTop,
      Value<String?> note,
    });

final class $$OutgoingRecipientsTableReferences
    extends
        BaseReferences<
          _$MailStore,
          $OutgoingRecipientsTable,
          OutgoingRecipient
        > {
  $$OutgoingRecipientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $OutgoingTable _outgoingIdTable(_$MailStore db) =>
      db.outgoing.createAlias('outgoing_recipients__outgoing_id__outgoing__id');

  $$OutgoingTableProcessedTableManager get outgoingId {
    final $_column = $_itemColumn<int>('outgoing_id')!;

    final manager = $$OutgoingTableTableManager(
      $_db,
      $_db.outgoing,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_outgoingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OutgoingRecipientsTableFilterComposer
    extends Composer<_$MailStore, $OutgoingRecipientsTable> {
  $$OutgoingRecipientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bbsBid => $composableBuilder(
    column: $table.bbsBid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get knownTop => $composableBuilder(
    column: $table.knownTop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$OutgoingTableFilterComposer get outgoingId {
    final $$OutgoingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outgoingId,
      referencedTable: $db.outgoing,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingTableFilterComposer(
            $db: $db,
            $table: $db.outgoing,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutgoingRecipientsTableOrderingComposer
    extends Composer<_$MailStore, $OutgoingRecipientsTable> {
  $$OutgoingRecipientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bbsNumber => $composableBuilder(
    column: $table.bbsNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bbsBid => $composableBuilder(
    column: $table.bbsBid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get knownTop => $composableBuilder(
    column: $table.knownTop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$OutgoingTableOrderingComposer get outgoingId {
    final $$OutgoingTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outgoingId,
      referencedTable: $db.outgoing,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingTableOrderingComposer(
            $db: $db,
            $table: $db.outgoing,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutgoingRecipientsTableAnnotationComposer
    extends Composer<_$MailStore, $OutgoingRecipientsTable> {
  $$OutgoingRecipientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get bbsNumber =>
      $composableBuilder(column: $table.bbsNumber, builder: (column) => column);

  GeneratedColumn<String> get bbsBid =>
      $composableBuilder(column: $table.bbsBid, builder: (column) => column);

  GeneratedColumn<int> get knownTop =>
      $composableBuilder(column: $table.knownTop, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$OutgoingTableAnnotationComposer get outgoingId {
    final $$OutgoingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.outgoingId,
      referencedTable: $db.outgoing,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutgoingTableAnnotationComposer(
            $db: $db,
            $table: $db.outgoing,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutgoingRecipientsTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $OutgoingRecipientsTable,
          OutgoingRecipient,
          $$OutgoingRecipientsTableFilterComposer,
          $$OutgoingRecipientsTableOrderingComposer,
          $$OutgoingRecipientsTableAnnotationComposer,
          $$OutgoingRecipientsTableCreateCompanionBuilder,
          $$OutgoingRecipientsTableUpdateCompanionBuilder,
          (OutgoingRecipient, $$OutgoingRecipientsTableReferences),
          OutgoingRecipient,
          PrefetchHooks Function({bool outgoingId})
        > {
  $$OutgoingRecipientsTableTableManager(
    _$MailStore db,
    $OutgoingRecipientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutgoingRecipientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutgoingRecipientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutgoingRecipientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> outgoingId = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> bbsNumber = const Value.absent(),
                Value<String?> bbsBid = const Value.absent(),
                Value<int?> knownTop = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => OutgoingRecipientsCompanion(
                id: id,
                outgoingId: outgoingId,
                address: address,
                state: state,
                bbsNumber: bbsNumber,
                bbsBid: bbsBid,
                knownTop: knownTop,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int outgoingId,
                required String address,
                Value<String> state = const Value.absent(),
                Value<int?> bbsNumber = const Value.absent(),
                Value<String?> bbsBid = const Value.absent(),
                Value<int?> knownTop = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => OutgoingRecipientsCompanion.insert(
                id: id,
                outgoingId: outgoingId,
                address: address,
                state: state,
                bbsNumber: bbsNumber,
                bbsBid: bbsBid,
                knownTop: knownTop,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutgoingRecipientsTable, OutgoingRecipient>(
                    table,
                  ),
                  $$OutgoingRecipientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({outgoingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (outgoingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.outgoingId,
                        referencedTable: $$OutgoingRecipientsTableReferences
                            ._outgoingIdTable(db),
                        referencedColumn: $$OutgoingRecipientsTableReferences
                            ._outgoingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OutgoingRecipientsTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $OutgoingRecipientsTable,
      OutgoingRecipient,
      $$OutgoingRecipientsTableFilterComposer,
      $$OutgoingRecipientsTableOrderingComposer,
      $$OutgoingRecipientsTableAnnotationComposer,
      $$OutgoingRecipientsTableCreateCompanionBuilder,
      $$OutgoingRecipientsTableUpdateCompanionBuilder,
      (OutgoingRecipient, $$OutgoingRecipientsTableReferences),
      OutgoingRecipient,
      PrefetchHooks Function({bool outgoingId})
    >;
typedef $$ContactsTableCreateCompanionBuilder = ContactsCompanion Function({
  required String callsign,
  Value<String?> name,
  Value<String?> homeBbs,
  Value<String?> notes,
  required String source,
  Value<bool> edited,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> callsign,
  Value<String?> name,
  Value<String?> homeBbs,
  Value<String?> notes,
  Value<String> source,
  Value<bool> edited,
  Value<int> rowid,
});

class $$ContactsTableFilterComposer
    extends Composer<_$MailStore, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeBbs => $composableBuilder(
    column: $table.homeBbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$MailStore, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeBbs => $composableBuilder(
    column: $table.homeBbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$MailStore, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get callsign =>
      $composableBuilder(column: $table.callsign, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get homeBbs =>
      $composableBuilder(column: $table.homeBbs, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, BaseReferences<_$MailStore, $ContactsTable, Contact>),
          Contact,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$MailStore db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> callsign = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> homeBbs = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                callsign: callsign,
                name: name,
                homeBbs: homeBbs,
                notes: notes,
                source: source,
                edited: edited,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String callsign,
                Value<String?> name = const Value.absent(),
                Value<String?> homeBbs = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String source,
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                callsign: callsign,
                name: name,
                homeBbs: homeBbs,
                notes: notes,
                source: source,
                edited: edited,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContactsTable, Contact>(table),
                  BaseReferences<_$MailStore, $ContactsTable, Contact>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, BaseReferences<_$MailStore, $ContactsTable, Contact>),
      Contact,
      PrefetchHooks Function()
    >;
typedef $$SubscriptionsTableCreateCompanionBuilder =
    SubscriptionsCompanion Function({
      Value<int> id,
      Value<String?> category,
      Value<String?> area,
    });
typedef $$SubscriptionsTableUpdateCompanionBuilder =
    SubscriptionsCompanion Function({
      Value<int> id,
      Value<String?> category,
      Value<String?> area,
    });

class $$SubscriptionsTableFilterComposer
    extends Composer<_$MailStore, $SubscriptionsTable> {
  $$SubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubscriptionsTableOrderingComposer
    extends Composer<_$MailStore, $SubscriptionsTable> {
  $$SubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubscriptionsTableAnnotationComposer
    extends Composer<_$MailStore, $SubscriptionsTable> {
  $$SubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);
}

class $$SubscriptionsTableTableManager
    extends
        RootTableManager<
          _$MailStore,
          $SubscriptionsTable,
          Subscription,
          $$SubscriptionsTableFilterComposer,
          $$SubscriptionsTableOrderingComposer,
          $$SubscriptionsTableAnnotationComposer,
          $$SubscriptionsTableCreateCompanionBuilder,
          $$SubscriptionsTableUpdateCompanionBuilder,
          (
            Subscription,
            BaseReferences<_$MailStore, $SubscriptionsTable, Subscription>,
          ),
          Subscription,
          PrefetchHooks Function()
        > {
  $$SubscriptionsTableTableManager(_$MailStore db, $SubscriptionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> area = const Value.absent(),
          }) => SubscriptionsCompanion(id: id, category: category, area: area),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> area = const Value.absent(),
              }) => SubscriptionsCompanion.insert(
                id: id,
                category: category,
                area: area,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubscriptionsTable, Subscription>(table),
                  BaseReferences<
                    _$MailStore,
                    $SubscriptionsTable,
                    Subscription
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$MailStore,
      $SubscriptionsTable,
      Subscription,
      $$SubscriptionsTableFilterComposer,
      $$SubscriptionsTableOrderingComposer,
      $$SubscriptionsTableAnnotationComposer,
      $$SubscriptionsTableCreateCompanionBuilder,
      $$SubscriptionsTableUpdateCompanionBuilder,
      (
        Subscription,
        BaseReferences<_$MailStore, $SubscriptionsTable, Subscription>,
      ),
      Subscription,
      PrefetchHooks Function()
    >;

class $MailStoreManager {
  final _$MailStore _db;
  $MailStoreManager(this._db);
  $$IdentitiesTableTableManager get identities =>
      $$IdentitiesTableTableManager(_db, _db.identities);
  $$ConnectionsTableTableManager get connections =>
      $$ConnectionsTableTableManager(_db, _db.connections);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$SentListingsTableTableManager get sentListings =>
      $$SentListingsTableTableManager(_db, _db.sentListings);
  $$OutgoingTableTableManager get outgoing =>
      $$OutgoingTableTableManager(_db, _db.outgoing);
  $$OutgoingRecipientsTableTableManager get outgoingRecipients =>
      $$OutgoingRecipientsTableTableManager(_db, _db.outgoingRecipients);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db, _db.subscriptions);
}
