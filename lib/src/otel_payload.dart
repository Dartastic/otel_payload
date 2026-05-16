// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_payload_suppression.dart';

const _tracerName = 'dartastic_otel_libs_payload';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class PayloadResult {
  const PayloadResult({
    this.docCount,
    this.totalDocs,
    this.totalPages,
    this.page,
    this.limit,
    this.depth,
    this.collection,
    this.draftMode,
    this.locale,
    this.versionId,
    this.deploymentTier,
    this.requestId,
    this.statusCode,
  });

  /// `docs.length`.
  final int? docCount;

  /// `totalDocs`.
  final int? totalDocs;

  final int? totalPages;
  final int? page;
  final int? limit;

  /// `depth` query param — number of relationship hops eagerly
  /// populated; the primary Payload cost/perf dim.
  final int? depth;

  /// Slug of the collection or global.
  final String? collection;

  /// `draft=true` was requested.
  final bool? draftMode;

  /// `en`, `de`, etc.
  final String? locale;

  /// Specific version doc ID when querying `/versions`.
  final String? versionId;

  /// `cloud` / `self_hosted` — Payload Cloud projects are tier-priced.
  final String? deploymentTier;

  /// `x-request-id`.
  final String? requestId;

  final int? statusCode;
}

class PayloadCallResult<T> {
  const PayloadCallResult({required this.value, this.result});
  final T value;
  final PayloadResult? result;
}

/// Wraps a Payload CMS API call in a CLIENT span. [operation] is one
/// of `find`, `findByID`, `create`, `update`, `delete`, `count`,
/// `findVersions`, `findVersionByID`, `restoreVersion`,
/// `globals.findOne`, `globals.update`, `graphql`.
Future<T> tracedPayload<T>({
  required String operation,
  required Future<PayloadCallResult<T>> Function() invoke,
  String? api,
  String? collection,
}) async {
  if (payloadInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'payload',
    'rpc.method': operation,
    'payload.operation': operation,
  };
  if (api != null) m['payload.api'] = api;
  if (collection != null) m['payload.collection'] = collection;

  final span = _tracer().startSpan(
    'payload $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.docCount != null) {
        extras.add(OTel.attributeInt(
          'payload.doc_count',
          r.result!.docCount!,
        ));
      }
      if (r.result!.totalDocs != null) {
        extras.add(OTel.attributeInt(
          'payload.total_docs',
          r.result!.totalDocs!,
        ));
      }
      if (r.result!.totalPages != null) {
        extras.add(OTel.attributeInt(
          'payload.total_pages',
          r.result!.totalPages!,
        ));
      }
      if (r.result!.page != null) {
        extras.add(OTel.attributeInt('payload.page', r.result!.page!));
      }
      if (r.result!.limit != null) {
        extras.add(OTel.attributeInt('payload.limit', r.result!.limit!));
      }
      if (r.result!.depth != null) {
        extras.add(OTel.attributeInt('payload.depth', r.result!.depth!));
      }
      if (r.result!.collection != null) {
        extras.add(OTel.attributeString(
          'payload.collection',
          r.result!.collection!,
        ));
      }
      if (r.result!.draftMode != null) {
        extras.add(OTel.attributeBool(
          'payload.draft_mode',
          r.result!.draftMode!,
        ));
      }
      if (r.result!.locale != null) {
        extras.add(OTel.attributeString(
          'payload.locale',
          r.result!.locale!,
        ));
      }
      if (r.result!.versionId != null) {
        extras.add(OTel.attributeString(
          'payload.version.id',
          r.result!.versionId!,
        ));
      }
      if (r.result!.deploymentTier != null) {
        extras.add(OTel.attributeString(
          'payload.deployment.tier',
          r.result!.deploymentTier!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'payload.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Payload HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
