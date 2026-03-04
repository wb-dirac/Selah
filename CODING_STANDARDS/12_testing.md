## 12. 测试规范

### 12.1 测试覆盖率要求

| 模块 | 最低行覆盖率 | 最低分支覆盖率 | 备注 |
|------|------------|--------------|------|
| `core/crypto` | **100%** | **100%** | 加密实现零容忍 |
| `core/keychain` | **100%** | **100%** | |
| `features/privacy` | **100%** | 95% | PII 检测 |
| `features/skill_sandbox` | 95% | 90% | |
| `features/llm_gateway` | 90% | 85% | |
| `features/tool_bridge` | 90% | 85% | |
| `features/a2a` | 90% | 85% | |
| `features/conversation` | 85% | 80% | |
| `shared/widgets` | 70% | — | Golden 测试补充 |
| `presentation` 层 | 70% | — | Widget 测试补充 |

### 12.2 单元测试规范

```dart
// 测试文件结构规范
void main() {
  // ✅ 使用 group 组织测试，group 名称 = 被测类/方法名
  group('LlmGateway', () {
    late MockKeychainService mockKeychain;
    late MockOpenAiProvider mockProvider;
    late LlmGateway gateway;

    // setUp 中创建 Mock，不在 test 内部
    setUp(() {
      mockKeychain = MockKeychainService();
      mockProvider = MockOpenAiProvider();
      gateway = LlmGateway(
        providers: [mockProvider],
        keychainService: mockKeychain,
      );
    });

    group('complete()', () {
      test('returns success when provider responds correctly', () async {
        // Arrange
        when(() => mockProvider.complete(any()))
          .thenAnswer((_) async => Result.success(fakeResponse));

        // Act
        final result = await gateway.complete(fakeRequest);

        // Assert
        expect(result, isA<Success<LlmResponse, LlmException>>());
        expect(result.value.content, equals(fakeResponse.content));
      });

      test('returns failure when API key is missing', () async {
        // Arrange
        when(() => mockKeychain.read(any()))
          .thenAnswer((_) async => null);  // Key 不存在

        // Act
        final result = await gateway.complete(fakeRequest);

        // Assert
        expect(result, isA<Failure<LlmResponse, LlmException>>());
        expect(result.failure, isA<ApiKeyNotFoundException>());
      });

      test('sanitizes PII before sending to cloud provider', () async {
        // Arrange
        final requestWithPii = LlmRequest(
          prompt: '我的手机号是 13812345678',
          provider: cloudProvider,
        );
        final capturedRequests = <LlmRequest>[];
        when(() => mockProvider.complete(captureAny()))
          .thenAnswer((inv) {
            capturedRequests.add(inv.positionalArguments[0] as LlmRequest);
            return Future.value(Result.success(fakeResponse));
          });

        // Act
        await gateway.complete(requestWithPii);

        // Assert：发出的请求不含原始手机号
        expect(capturedRequests.single.prompt, isNot(contains('13812345678')));
      });
    });
  });
}

// Mock 命名规范：Mock + 接口名
// 使用 mocktail 生成，不手写 Mock 实现
class MockKeychainService extends Mock implements KeychainService {}
class MockOpenAiProvider extends Mock implements LlmProvider {}
```

### 12.3 集成测试规范

```dart
// 集成测试使用真实的本地数据库（内存模式）和 Mock 网络
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationFlow Integration', () {
    late TestDatabase testDb;
    late MockLlmGateway mockGateway;
    late ProviderContainer container;

    setUp(() async {
      testDb = await TestDatabase.createInMemory();
      mockGateway = MockLlmGateway();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((_) => testDb),
          llmGatewayProvider.overrideWith((_) => mockGateway),
        ],
      );
    });

    tearDown(() async {
      await testDb.close();
      container.dispose();
    });

    testWidgets('sends message and displays response', (tester) async {
      // 构建完整的 Widget 树（不是孤立 Widget）
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const AppRoot(),
        ),
      );

      // 模拟用户操作
      await tester.enterText(find.byType(MessageInputField), 'Hello');
      await tester.tap(find.byType(SendButton));
      await tester.pump();

      // 验证 loading 状态
      expect(find.byType(MessageLoadingIndicator), findsOneWidget);

      // 等待响应
      await tester.pumpAndSettle();

      // 验证消息显示
      expect(find.text('Hello'), findsOneWidget);  // 用户消息
      expect(find.text(fakeResponse.content), findsOneWidget);  // AI 响应
    });
  });
}
```

### 12.4 安全专项测试规范

```dart
// 安全测试独立放在 test/security/ 目录
// 这些测试必须在 CI 中强制通过，不允许跳过

void main() {
  group('Security Tests', () {

    group('API Key Isolation', () {
      test('API key never appears in application logs', () async {
        final logCapture = LogCaptureService();
        final keychain = MockKeychainService();
        when(() => keychain.read(any())).thenReturn(Future.value('sk-test-key-12345'));

        final gateway = LlmGateway(keychainService: keychain, ...);
        await gateway.complete(request);

        for (final logEntry in logCapture.entries) {
          expect(logEntry.message, isNot(contains('sk-test-key-12345')));
        }
      });

      test('API key is not stored in SharedPreferences', () async {
        final fakePrefs = FakeSharedPreferences();
        // 配置保存流程
        await configService.saveProvider(providerConfig);
        // 验证 SharedPreferences 中没有 Key
        for (final key in fakePrefs.keys) {
          expect(fakePrefs.getString(key), isNot(contains('sk-')));
        }
      });
    });

    group('Sandbox Isolation', () {
      test('skill cannot read files outside sandbox directory', () async {
        final sandbox = await createTestSandbox();
        final result = await sandbox.execute(
          scriptPath: 'escape_attempt.py',
          args: {'target': '/etc/hosts'},
        );
        expect(result.isFailure, isTrue);
        expect(result.failure, isA<SandboxSecurityException>());
      });

      test('skill execution is terminated after timeout', () async {
        final sandbox = await createTestSandbox();
        final stopwatch = Stopwatch()..start();
        await sandbox.execute(
          scriptPath: 'infinite_loop.py',
          args: {},
          timeout: const Duration(seconds: 3),
        );
        stopwatch.stop();
        // 允许 500ms 误差
        expect(stopwatch.elapsedMilliseconds, lessThan(3500));
      });
    });

    group('Encryption Correctness', () {
      test('decryption with wrong key fails with exception, not garbage data', () async {
        final crypto = CryptoServiceImpl();
        final ct = await crypto.encrypt(Uint8List.fromList([1,2,3]), correctKey);
        expect(
          () async => await crypto.decrypt(ct, wrongKey),
          throwsA(isA<DecryptionException>()),
        );
      });

      test('nonce is unique across 1000 encryptions', () async {
        final crypto = CryptoServiceImpl();
        final nonces = <String>{};
        for (int i = 0; i < 1000; i++) {
          final ct = await crypto.encrypt(plaintext, key);
          final nonce = base64.encode(ct.sublist(0, 12));
          expect(nonces.add(nonce), isTrue, reason: 'Nonce collision at $i');
        }
      });
    });

    group('PII Detection', () {
      test('detects Chinese phone numbers', () async {
        final detector = PiiDetector();
        final result = await detector.detect('联系我 13812345678');
        expect(result.hasPii, isTrue);
        expect(result.sanitized, isNot(contains('13812345678')));
      });

      test('detects API keys in user input', () async {
        final detector = PiiDetector();
        final result = await detector.detect('我的 key 是 sk-ant-api01-abcdef');
        expect(result.hasPii, isTrue);
      });
    });
  });
}
```

### 12.5 性能基准测试规范

```dart
// 性能基准测试放在 test/performance/
// 基准值来源：PRD 5.1 性能要求

void main() {
  group('Performance Benchmarks', () {
    test('app cold start completes within 2 seconds', () async {
      final stopwatch = Stopwatch()..start();
      await AppInitializer().initialize();
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
        reason: 'Cold start exceeded 2s SLA');
    });

    test('SQLite conversation list query under 100ms for 1000 records', () async {
      await _seedDatabase(1000);
      final stopwatch = Stopwatch()..start();
      await conversationRepository.getAll(limit: 50);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('local OCR completes within 1 second for standard image', () async {
      final testImage = await _loadTestImage('menu_photo.jpg');
      final stopwatch = Stopwatch()..start();
      await ocrService.extract(testImage);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
        reason: 'OCR exceeded 1s SLA');
    });
  });
}
```

### 12.6 Golden 测试规范

```dart
// 生成式 UI 卡片必须有 Golden 测试，防止视觉回归
void main() {
  testWidgets('TrainCardWidget golden test - standard state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TrainCardWidget(
            card: TrainCard.testFixture(),
            onAddToCalendar: () {},
            onBookTicket: () {},
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TrainCardWidget),
      matchesGoldenFile('golden/train_card_standard.png'),
    );
  });

  testWidgets('TrainCardWidget golden test - delayed state', (tester) async {
    // 延误态的视觉必须经过 Golden 验证
    await tester.pumpWidget(/* ... delayed train ... */);
    await expectLater(
      find.byType(TrainCardWidget),
      matchesGoldenFile('golden/train_card_delayed.png'),
    );
  });
}
```

---

