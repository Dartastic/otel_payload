// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_payload/otel_payload.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_payload-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('find records depth + collection + draft + tier', () async {
    await tracedPayload<String>(
      operation: 'find',
      api: 'rest',
      invoke: () async => const PayloadCallResult(
        value: 'ok',
        result: PayloadResult(
          docCount: 10,
          totalDocs: 250,
          totalPages: 25,
          page: 1,
          limit: 10,
          depth: 4,
          collection: 'posts',
          draftMode: true,
          locale: 'en',
          deploymentTier: 'cloud',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('payload find')!);
    expect(a['payload.api'], 'rest');
    expect(a['payload.depth'], 4);
    expect(a['payload.collection'], 'posts');
    expect(a['payload.draft_mode'], true);
    expect(a['payload.deployment.tier'], 'cloud');
  });

  test('restoreVersion records version.id', () async {
    await tracedPayload<String>(
      operation: 'restoreVersion',
      invoke: () async => const PayloadCallResult(
        value: 'ok',
        result: PayloadResult(versionId: 'v-42'),
      ),
    );
    final a = attrsOf(spans.findSpanByName('payload restoreVersion')!);
    expect(a['payload.version.id'], 'v-42');
  });

  test('suppression skips spans', () async {
    await runWithoutPayloadInstrumentationAsync(() async {
      await tracedPayload<String>(
        operation: 'find',
        invoke: () async => const PayloadCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('payload '), isEmpty);
  });
}
