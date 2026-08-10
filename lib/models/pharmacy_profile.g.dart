// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacy_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PharmacyProfileAdapter extends TypeAdapter<PharmacyProfile> {
  @override
  final int typeId = 8;

  @override
  PharmacyProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PharmacyProfile(
      id: fields[0] as String,
      pharmacyName: fields[1] as String,
      address: fields[2] as String?,
      phone: fields[3] as String?,
      email: fields[4] as String?,
      website: fields[5] as String?,
      logoPath: fields[6] as String?,
      taxId: fields[7] as String?,
      licenseNumber: fields[8] as String?,
      receiptFooter: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PharmacyProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pharmacyName)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.website)
      ..writeByte(6)
      ..write(obj.logoPath)
      ..writeByte(7)
      ..write(obj.taxId)
      ..writeByte(8)
      ..write(obj.licenseNumber)
      ..writeByte(9)
      ..write(obj.receiptFooter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PharmacyProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
