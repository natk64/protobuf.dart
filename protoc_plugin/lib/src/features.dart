import 'dart:convert';

import 'gen/google/protobuf/descriptor.pb.dart';

// Base64 encoded FeatureSetDefaults message
const _featureSetDefaultsProto =
    'ChcYhAciACoQCAEQAhgCIAMoATACOAJAAQoXGOcHIgAqEAgCEAEYASACKAEwATgCQAEKFxjoByIMCAEQARgBIAIoATABKgQ4AkABIOYHKOgH';

Edition fileEdition(FileDescriptorProto desc) => switch (desc.syntax) {
  "editions" => desc.edition,
  "proto3" => Edition.EDITION_PROTO3,
  _ => Edition.EDITION_PROTO2,
};

FeatureSet defaultFeatures(Edition edition) {
  final featureSetDefaults = FeatureSetDefaults.fromBuffer(
    base64Decode(_featureSetDefaultsProto),
  );

  if (edition.value < featureSetDefaults.minimumEdition.value ||
      edition.value > featureSetDefaults.maximumEdition.value) {
    throw 'edition out of range';
  }

  FeatureSetDefaults_FeatureSetEditionDefault editionDefaults =
      featureSetDefaults.defaults.lastWhere(
        (editionDefaults) => editionDefaults.edition.value <= edition.value,
      );

  FeatureSet defaultFeatures = editionDefaults.fixedFeatures;
  defaultFeatures.mergeFromMessage(editionDefaults.overridableFeatures);

  return defaultFeatures;
}

FeatureSet mergeFeatures(FeatureSet parent, FeatureSet? override) {
  if (override == null) {
    return parent;
  }

  FeatureSet merged = parent.deepCopy();
  merged.mergeFromMessage(override);
  return merged;
}

bool shouldPack(
  FieldDescriptorProto descriptor,
  Edition edition,
  FeatureSet features,
) {
  switch (edition) {
    case Edition.EDITION_PROTO3:
      if (!descriptor.hasOptions()) {
        return true; // packed by default in proto3
      } else {
        return !descriptor.options.hasPacked() || descriptor.options.packed;
      }
    case Edition.EDITION_PROTO2:
      if (!descriptor.hasOptions()) {
        return false; // not packed by default in proto3
      } else {
        return descriptor.options.packed;
      }
    default:
      return features.repeatedFieldEncoding ==
          FeatureSet_RepeatedFieldEncoding.PACKED;
  }
}

bool hasFieldPresence(
  FieldDescriptorProto descriptor,
  Edition edition,
  FeatureSet features,
) {
  switch (edition) {
    case Edition.EDITION_PROTO3:
      return true;
    case Edition.EDITION_PROTO2:
      return true;
    default:
      return features.fieldPresence != FeatureSet_FieldPresence.IMPLICIT;
  }
}
