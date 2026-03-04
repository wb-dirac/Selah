## 11. 生成式 UI 编码规范

### 11.1 Schema 解析规范

```dart
// 所有生成式 UI 数据来源（LLM 输出或 Skill 输出）都是不可信的
// 必须严格校验 Schema，不得对 dynamic 数据做隐式转换

abstract class UiSchemaParser<T extends UiCard> {
  /// 解析结果必须是 Result，不得抛出异常
  Result<T, SchemaParseException> parse(Map<String, dynamic> raw);
}

class TrainCardParser implements UiSchemaParser<TrainCard> {
  @override
  Result<TrainCard, SchemaParseException> parse(Map<String, dynamic> raw) {
    try {
      // 每个字段都必须显式提取和类型检查
      final departure = raw['departure'] as Map<String, dynamic>?;
      if (departure == null) {
        return Result.failure(MissingFieldException('departure'));
      }

      final departureTime = DateTime.tryParse(
        departure['time'] as String? ?? '',
      );
      if (departureTime == null) {
        return Result.failure(InvalidFieldException('departure.time'));
      }

      // 价格必须是数字，不能直接 as String
      final price = switch (raw['price']) {
        int p => p.toDouble(),
        double p => p,
        String s => double.tryParse(s),
        _ => null,
      };
      if (price == null) {
        return Result.failure(InvalidFieldException('price'));
      }

      return Result.success(TrainCard(
        departureTime: departureTime,
        price: price,
        // ... 其余字段
      ));
    } catch (e) {
      return Result.failure(SchemaParseException(raw: raw, cause: e));
    }
  }
}
```

### 11.2 卡片 Widget 规范

```dart
// 所有生成式 UI 卡片 Widget 必须：
// 1. 是 StatelessWidget（状态由 ViewModel 管理）
// 2. 接受强类型数据模型，不接受 Map<String, dynamic>
// 3. 所有用户操作通过回调传出，不在内部发起网络/数据库操作

class TrainCardWidget extends StatelessWidget {
  const TrainCardWidget({
    super.key,
    required this.card,
    required this.onAddToCalendar,    // ✅ 回调，不在内部实现
    required this.onBookTicket,
  });

  final TrainCard card;              // ✅ 强类型
  final VoidCallback onAddToCalendar;
  final VoidCallback onBookTicket;

  @override
  Widget build(BuildContext context) {
    // 只有 UI 代码
    return AppCard(
      typeLabel: '高铁信息',
      child: Column(
        children: [
          _buildRouteRow(),
          _buildInfoRow(),
          _buildActionRow(),
        ],
      ),
    );
  }
}
```

---

