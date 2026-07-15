import 'package:Vista/features/chat/services/sse_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates event IDs and evicts oldest IDs at a fixed bound', () {
    final deduplicator = RealtimeEventDeduplicator(capacity: 2);

    expect(deduplicator.accept({'event_id': 'a'}), isTrue);
    expect(deduplicator.accept({'event_id': 'a'}), isFalse);
    expect(deduplicator.accept({'event_id': 'b'}), isTrue);
    expect(deduplicator.accept({'event_id': 'c'}), isTrue);
    expect(deduplicator.accept({'event_id': 'a'}), isTrue);
  });

  test('accepts legacy events without event IDs', () {
    final deduplicator = RealtimeEventDeduplicator(capacity: 2);

    expect(deduplicator.accept({'type': 'typing'}), isTrue);
    expect(deduplicator.accept({'type': 'typing'}), isTrue);
  });
}
