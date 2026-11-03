import 'dart:async';

import 'package:test/test.dart';

import '../dart_async.dart';

class ErroringAsyncParser extends AsyncParser {
  @override
  Future<String> asString(int delayMs, int value) async => value.toString();

  @override
  Future<int> tryFromString(int delayMs, String value) async {
    if (value == 'bad') {
      throw NotAnIntParserException();
    }
    if (value == 'unexpected') {
      throw StateError('unexpected value');
    }
    return int.parse(value);
  }

  @override
  Future<void> delay(int delayMs) async {}

  @override
  Future<void> tryDelay(String delayMs) async {
    if (delayMs == 'bad') {
      throw NotAnIntParserException();
    }
  }
}

class DedupAsyncParser extends AsyncParserMirror {
  @override
  Future<String> mirrorString(int delayMs, int value) async => 'mirror:$value';

  @override
  Future<void> mirrorDelay(int delayMs) async {}
}

class ControlledAsyncParser extends ErroringAsyncParser {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> delay(int delayMs) {
    started.complete();
    return release.future;
  }
}

void main() {
  initialize();
  ensureInitialized();

  test('greet', () {
    expect(greet(who: 'Somebody'), 'Hello, Somebody');
  });

  test('always_ready', () async {
    expect(await alwaysReady(), isTrue);
  });

  test('void', () async {
    await void_();
  });

  test('sleep', () async {
    expect(await sleep(ms: 0), isTrue);
  });

  test('sequential_future', () async {
    expect(await sayAfter(ms: 0, who: 'Alice'), 'Hello, Alice!');
    expect(await sayAfter(ms: 0, who: 'Bob'), 'Hello, Bob!');
  });

  test('concurrent_future', () async {
    expect(
      await Future.wait([
        sayAfter(ms: 0, who: 'Alice'),
        sayAfter(ms: 0, who: 'Bob'),
      ]),
      ['Hello, Alice!', 'Hello, Bob!'],
    );
  });

  test('pending Rust future suspends without blocking another call', () async {
    final parser = ControlledAsyncParser();
    var completed = false;
    final pending = delayUsingTrait(
      obj: parser,
      delayMs: 0,
    ).then((_) => completed = true);
    try {
      await parser.started.future;
      expect(completed, isFalse);
      // Completion of this call proves the first call yielded. The controlled
      // callback stays pending regardless of host scheduling or clock changes.
      await delayUsingTrait(obj: ErroringAsyncParser(), delayMs: 0);
      expect(completed, isFalse);
    } finally {
      parser.release.complete();
      await pending;
    }
    expect(completed, isTrue);
  });

  test('with_tokio_runtime', () async {
    expect(
      await sayAfterWithTokio(ms: 0, who: 'Alice'),
      'Hello, Alice (with Tokio)!',
    );
  });

  test('fallible_function_and_method', () async {
    expect(await fallibleMe(doFail: false), 42);
    await expectLater(fallibleMe(doFail: true), throwsA(isA<MyException>()));
  });

  test('record', () async {
    final result = await newMyRecord(a: 'foo', b: 42);
    expect(result.a, 'foo');
    expect(result.b, 42);
  });

  for (final tokio in [false, true]) {
    test('Rust future suspension and cross-thread wakes (tokio: $tokio)', () async {
      final gate = WakeGate();
      var completed = false;
      final pending = (tokio ? gate.waitWithTokio() : gate.wait())
          .then((_) => completed = true);
      try {
        // A Rust-only call must progress while the first Rust future is still
        // waiting for work. This also drains queued native callbacks, so an
        // incorrectly completed pending future cannot hide in the event queue.
        expect(await sayAfter(ms: 0, who: 'Bob'), 'Hello, Bob!');
        expect(completed, isFalse);
      } finally {
        gate.release(); // duplicate wakeups from joined Rust worker threads
        await pending;
      }
      expect(completed, isTrue);
      // The generated continuation and Rust future have now been freed. Wake
      // again from a Rust worker, then drain queued native callbacks.
      gate.wakeAgain();
      await void_();
      gate.dispose();
    });
  }

  test('udl_async_function', () async {
    expect(await alwaysReady(), isTrue);
  });

  test('proc_macro_megaphone_async_constructor', () async {
    final megaphone = await Megaphone.new_();
    expect(megaphone, isNotNull);
    megaphone.dispose();
  });

  test('proc_macro_megaphone_secondary_constructor', () async {
    final megaphone = await Megaphone.secondary();
    expect(megaphone, isNotNull);
    megaphone.dispose();
  });

  test('proc_macro_megaphone_async_methods', () async {
    final megaphone = await Megaphone.new_();
    expect(await megaphone.sayAfter(ms: 0, who: 'Alice'), 'HELLO, ALICE!');
    expect(await megaphone.silence(), '');
    megaphone.dispose();
  });

  test('proc_macro_megaphone_sync_method', () async {
    final megaphone = await Megaphone.new_();
    expect(megaphone.sayNow(who: 'Bob'), 'HELLO, BOB!');
    megaphone.dispose();
  });

  test('proc_macro_megaphone_tokio_method', () async {
    final megaphone = await Megaphone.new_();
    expect(
      await megaphone.sayAfterWithTokio(ms: 0, who: 'Charlie'),
      'HELLO, CHARLIE (WITH TOKIO)!',
    );
    megaphone.dispose();
  });

  test('proc_macro_megaphone_fallible_method', () async {
    final megaphone = await Megaphone.new_();
    expect(await megaphone.fallibleMe(doFail: false), 42);
    await expectLater(
      megaphone.fallibleMe(doFail: true),
      throwsA(isA<MyException>()),
    );
    megaphone.dispose();
  });

  test('udl_megaphone_async_constructors', () async {
    final primary = await UdlMegaphone.new_();
    final secondary = await UdlMegaphone.secondary();
    expect(primary, isNotNull);
    expect(secondary, isNotNull);
    primary.dispose();
    secondary.dispose();
  });

  test('udl_megaphone_async_method', () async {
    final megaphone = await UdlMegaphone.new_();
    expect(
      await megaphone.sayAfter(ms: 0, who: 'Dave'),
      'HELLO, DAVE (FROM UDL MEGAPHONE)!',
    );
    megaphone.dispose();
  });

  test('async_object_creation_functions', () async {
    final syncMegaphone = newMegaphone();
    expect(syncMegaphone, isNotNull);
    final asyncMegaphone = await asyncNewMegaphone();
    expect(asyncMegaphone, isNotNull);
    final maybeMegaphone = await asyncMaybeNewMegaphone(y: true);
    expect(maybeMegaphone, isNotNull);
    expect(await asyncMaybeNewMegaphone(y: false), isNull);
    syncMegaphone.dispose();
    asyncMegaphone.dispose();
    maybeMegaphone!.dispose();
  });

  test('async_function_with_object_parameter', () async {
    final megaphone = await Megaphone.new_();
    expect(
      await sayAfterWithMegaphone(megaphone: megaphone, ms: 0, who: 'Eve'),
      'HELLO, EVE!',
    );
    megaphone.dispose();
  });

  test('fallible_struct_creation', () async {
    final result = await fallibleStruct(doFail: false);
    expect(result, isNotNull);
    await expectLater(
      fallibleStruct(doFail: true),
      throwsA(isA<MyException>()),
    );
    result.dispose();
  });

  test('fallible_async_constructor', () async {
    await expectLater(FallibleMegaphone.new_(), throwsA(isA<MyException>()));
  });

  test('decode sequence of records containing payload enums', () {
    final items = listAsyncItems();
    expect(items.length, 2);

    final firstState = items[0].state as ReadyAsyncItemState;
    expect(items[0].id, 1);
    expect(firstState.timestampMs, 1111);

    final secondState = items[1].state as PendingAsyncItemState;
    expect(items[1].id, 2);
    expect(secondState.reason, 'syncing');
  });

  test('async callback preserves expected parser error', () async {
    final parser = ErroringAsyncParser();
    expect(
      () => tryFromStringUsingTrait(obj: parser, delayMs: 0, value: 'bad'),
      throwsA(isA<NotAnIntParserException>()),
    );
  });

  test('async void callback preserves expected parser error', () async {
    final parser = ErroringAsyncParser();
    expect(
      () => tryDelayUsingTrait(obj: parser, delayMs: 'bad'),
      throwsA(isA<NotAnIntParserException>()),
    );
  });

  test('async callback maps unexpected parser exception', () async {
    final parser = ErroringAsyncParser();
    expect(
      () =>
          tryFromStringUsingTrait(obj: parser, delayMs: 0, value: 'unexpected'),
      throwsA(isA<UnexpectedExceptionParserException>()),
    );
  });

  test(
    'async callback helper definitions are shared across interfaces',
    () async {
      final parser = DedupAsyncParser();

      expect(
        await mirrorStringUsingTrait(obj: parser, delayMs: 0, value: 42),
        equals('mirror:42'),
      );
      await mirrorDelayUsingTrait(obj: parser, delayMs: 0);
    },
  );
}
