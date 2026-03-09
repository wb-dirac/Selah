import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/generative_ui_layout.dart';

abstract class UiComponentData {
  const UiComponentData();

  String get uiType;
  String get typeLabel;
}

class ProductCardData extends UiComponentData {
  const ProductCardData({
    required this.name,
    required this.price,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    this.description,
    this.highlights = const <String>[],
  });

  final String name;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final String? description;
  final List<String> highlights;

  @override
  String get typeLabel => '🛍️ 商品推荐';

  @override
  String get uiType => 'product_card';
}

class WeatherForecastItem {
  const WeatherForecastItem({
    required this.day,
    required this.condition,
    required this.temperatureRange,
    this.suggestion,
  });

  final String day;
  final String condition;
  final String temperatureRange;
  final String? suggestion;
}

class WeatherCardData extends UiComponentData {
  const WeatherCardData({
    required this.city,
    required this.temperature,
    required this.condition,
    this.feelsLike,
    this.forecast = const <WeatherForecastItem>[],
  });

  final String city;
  final String temperature;
  final String condition;
  final String? feelsLike;
  final List<WeatherForecastItem> forecast;

  @override
  String get typeLabel => '🌤️ 天气';

  @override
  String get uiType => 'weather_card';
}

class ContactCardData extends UiComponentData {
  const ContactCardData({
    required this.name,
    this.title,
    this.organization,
    this.phone,
    this.email,
    this.sourceLabel,
  });

  final String name;
  final String? title;
  final String? organization;
  final String? phone;
  final String? email;
  final String? sourceLabel;

  @override
  String get typeLabel => '👤 联系人';

  @override
  String get uiType => 'contact_card';
}

class CalendarEventCardData extends UiComponentData {
  const CalendarEventCardData({
    required this.title,
    required this.dateText,
    required this.timeText,
    this.location,
    this.reminder,
    this.added = false,
  });

  final String title;
  final String dateText;
  final String timeText;
  final String? location;
  final String? reminder;
  final bool added;

  @override
  String get typeLabel => '📅 日历事件';

  @override
  String get uiType => 'calendar_event';
}

class MapPreviewCardData extends UiComponentData {
  const MapPreviewCardData({
    required this.title,
    required this.routeText,
    this.durationText,
    this.note,
  });

  final String title;
  final String routeText;
  final String? durationText;
  final String? note;

  @override
  String get typeLabel => '📍 地图预览';

  @override
  String get uiType => 'map_preview';
}

class TrainCardData extends UiComponentData {
  const TrainCardData({
    required this.trainNumber,
    required this.departureStation,
    required this.arrivalStation,
    required this.departureTime,
    required this.arrivalTime,
    this.duration,
    this.price,
    this.seatType,
    this.dateText,
    this.availability,
  });

  final String trainNumber;
  final String departureStation;
  final String arrivalStation;
  final String departureTime;
  final String arrivalTime;
  final String? duration;
  final String? price;
  final String? seatType;
  final String? dateText;
  final String? availability;

  @override
  String get typeLabel => '🚂 高铁信息';

  @override
  String get uiType => 'train_card';
}

class FlightCardData extends UiComponentData {
  const FlightCardData({
    required this.flightNumber,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureTime,
    required this.arrivalTime,
    this.duration,
    this.status,
    this.aircraft,
  });

  final String flightNumber;
  final String departureAirport;
  final String arrivalAirport;
  final String departureTime;
  final String arrivalTime;
  final String? duration;
  final String? status;
  final String? aircraft;

  @override
  String get typeLabel => '✈️ 航班信息';

  @override
  String get uiType => 'flight_card';
}

class CodeBlockCardData extends UiComponentData {
  const CodeBlockCardData({
    required this.language,
    required this.code,
    this.canRun = false,
  });

  final String language;
  final String code;
  final bool canRun;

  @override
  String get typeLabel => '💻 代码块';

  @override
  String get uiType => 'code_block';
}

class TaskListItemData {
  const TaskListItemData({
    required this.title,
    this.completed = false,
    this.dueText,
  });

  final String title;
  final bool completed;
  final String? dueText;
}

class TaskListCardData extends UiComponentData {
  const TaskListCardData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<TaskListItemData> items;

  @override
  String get typeLabel => '📋 任务清单';

  @override
  String get uiType => 'task_list';
}

class PriceChartPoint {
  const PriceChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class PriceChartCardData extends UiComponentData {
  const PriceChartCardData({
    required this.title,
    required this.points,
    this.currencySymbol = '¥',
  });

  final String title;
  final List<PriceChartPoint> points;
  final String currencySymbol;

  @override
  String get typeLabel => '📈 价格走势';

  @override
  String get uiType => 'price_chart';
}

class UnknownUiComponentData extends UiComponentData {
  const UnknownUiComponentData({
    required this.uiTypeName,
    required this.raw,
    required this.error,
  });

  final String uiTypeName;
  final Map<String, dynamic> raw;
  final String error;

  @override
  String get typeLabel => '🧩 未知组件';

  @override
  String get uiType => uiTypeName;
}

class UiParseResult<T extends UiComponentData> {
  const UiParseResult._({this.data, this.error});

  const UiParseResult.success(T value) : this._(data: value);

  const UiParseResult.failure(String message) : this._(error: message);

  final T? data;
  final String? error;

  bool get isSuccess => data != null;
}

abstract class UiSchemaParser<T extends UiComponentData> {
  UiParseResult<T> parse(Map<String, dynamic> raw);
}

class ProductCardParser implements UiSchemaParser<ProductCardData> {
  const ProductCardParser();

  @override
  UiParseResult<ProductCardData> parse(Map<String, dynamic> raw) {
    final name = _asString(raw['name']);
    final price = _asDouble(raw['price']);
    if (name == null) {
      return const UiParseResult.failure('缺少 product_card.name');
    }
    if (price == null) {
      return const UiParseResult.failure('缺少 product_card.price');
    }

    return UiParseResult.success(
      ProductCardData(
        name: name,
        price: price,
        originalPrice: _asDouble(raw['original_price']),
        rating: _asDouble(raw['rating']),
        reviewCount: _asInt(raw['review_count']),
        description: _asString(raw['description']),
        highlights: _asStringList(raw['highlights']),
      ),
    );
  }
}

class WeatherCardParser implements UiSchemaParser<WeatherCardData> {
  const WeatherCardParser();

  @override
  UiParseResult<WeatherCardData> parse(Map<String, dynamic> raw) {
    final city = _asString(raw['city']);
    final temperature = _asString(raw['temperature']);
    final condition = _asString(raw['condition']);
    if (city == null || temperature == null || condition == null) {
      return const UiParseResult.failure('weather_card 缺少 city / temperature / condition');
    }

    final forecast = _asMapList(raw['forecast'])
        .map(
          (item) => WeatherForecastItem(
            day: _asString(item['day']) ?? '未知',
            condition: _asString(item['condition']) ?? '未知',
            temperatureRange: _asString(item['temperature_range']) ?? '-',
            suggestion: _asString(item['suggestion']),
          ),
        )
        .toList(growable: false);

    return UiParseResult.success(
      WeatherCardData(
        city: city,
        temperature: temperature,
        condition: condition,
        feelsLike: _asString(raw['feels_like']),
        forecast: forecast,
      ),
    );
  }
}

class ContactCardParser implements UiSchemaParser<ContactCardData> {
  const ContactCardParser();

  @override
  UiParseResult<ContactCardData> parse(Map<String, dynamic> raw) {
    final name = _asString(raw['name']);
    if (name == null) {
      return const UiParseResult.failure('缺少 contact_card.name');
    }

    return UiParseResult.success(
      ContactCardData(
        name: name,
        title: _asString(raw['title']),
        organization: _asString(raw['organization']),
        phone: _asString(raw['phone']),
        email: _asString(raw['email']),
        sourceLabel: _asString(raw['source_label']),
      ),
    );
  }
}

class CalendarEventCardParser implements UiSchemaParser<CalendarEventCardData> {
  const CalendarEventCardParser();

  @override
  UiParseResult<CalendarEventCardData> parse(Map<String, dynamic> raw) {
    final title = _asString(raw['title']);
    final dateText = _asString(raw['date_text']);
    final timeText = _asString(raw['time_text']);
    if (title == null || dateText == null || timeText == null) {
      return const UiParseResult.failure('calendar_event 缺少 title / date_text / time_text');
    }

    return UiParseResult.success(
      CalendarEventCardData(
        title: title,
        dateText: dateText,
        timeText: timeText,
        location: _asString(raw['location']),
        reminder: _asString(raw['reminder']),
        added: raw['added'] as bool? ?? false,
      ),
    );
  }
}

class MapPreviewCardParser implements UiSchemaParser<MapPreviewCardData> {
  const MapPreviewCardParser();

  @override
  UiParseResult<MapPreviewCardData> parse(Map<String, dynamic> raw) {
    final title = _asString(raw['title']);
    final routeText = _asString(raw['route_text']);
    if (title == null || routeText == null) {
      return const UiParseResult.failure('map_preview 缺少 title / route_text');
    }

    return UiParseResult.success(
      MapPreviewCardData(
        title: title,
        routeText: routeText,
        durationText: _asString(raw['duration_text']),
        note: _asString(raw['note']),
      ),
    );
  }
}

class TrainCardParser implements UiSchemaParser<TrainCardData> {
  const TrainCardParser();

  @override
  UiParseResult<TrainCardData> parse(Map<String, dynamic> raw) {
    final trainNumber = _asString(raw['train_number']);
    final departureStation = _asString(raw['departure_station']);
    final arrivalStation = _asString(raw['arrival_station']);
    final departureTime = _asString(raw['departure_time']);
    final arrivalTime = _asString(raw['arrival_time']);
    if (trainNumber == null ||
        departureStation == null ||
        arrivalStation == null ||
        departureTime == null ||
        arrivalTime == null) {
      return const UiParseResult.failure(
        'train_card 缺少 train_number / departure_station / arrival_station / departure_time / arrival_time',
      );
    }

    return UiParseResult.success(
      TrainCardData(
        trainNumber: trainNumber,
        departureStation: departureStation,
        arrivalStation: arrivalStation,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        duration: _asString(raw['duration']),
        price: _asString(raw['price']),
        seatType: _asString(raw['seat_type']),
        dateText: _asString(raw['date_text']),
        availability: _asString(raw['availability']),
      ),
    );
  }
}

class FlightCardParser implements UiSchemaParser<FlightCardData> {
  const FlightCardParser();

  @override
  UiParseResult<FlightCardData> parse(Map<String, dynamic> raw) {
    final flightNumber = _asString(raw['flight_number']);
    final departureAirport = _asString(raw['departure_airport']);
    final arrivalAirport = _asString(raw['arrival_airport']);
    final departureTime = _asString(raw['departure_time']);
    final arrivalTime = _asString(raw['arrival_time']);
    if (flightNumber == null ||
        departureAirport == null ||
        arrivalAirport == null ||
        departureTime == null ||
        arrivalTime == null) {
      return const UiParseResult.failure(
        'flight_card 缺少 flight_number / departure_airport / arrival_airport / departure_time / arrival_time',
      );
    }

    return UiParseResult.success(
      FlightCardData(
        flightNumber: flightNumber,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        duration: _asString(raw['duration']),
        status: _asString(raw['status']),
        aircraft: _asString(raw['aircraft']),
      ),
    );
  }
}

class CodeBlockCardParser implements UiSchemaParser<CodeBlockCardData> {
  const CodeBlockCardParser();

  @override
  UiParseResult<CodeBlockCardData> parse(Map<String, dynamic> raw) {
    final language = _asString(raw['language']);
    final code = _asString(raw['code']);
    if (language == null || code == null) {
      return const UiParseResult.failure('code_block 缺少 language / code');
    }

    return UiParseResult.success(
      CodeBlockCardData(
        language: language,
        code: code,
        canRun: raw['can_run'] as bool? ?? false,
      ),
    );
  }
}

class TaskListCardParser implements UiSchemaParser<TaskListCardData> {
  const TaskListCardParser();

  @override
  UiParseResult<TaskListCardData> parse(Map<String, dynamic> raw) {
    final title = _asString(raw['title']);
    final itemsRaw = _asMapList(raw['items']);
    if (title == null) {
      return const UiParseResult.failure('task_list 缺少 title');
    }

    final items = itemsRaw
        .map(
          (item) => TaskListItemData(
            title: _asString(item['title']) ?? '未命名任务',
            completed: item['completed'] as bool? ?? false,
            dueText: _asString(item['due_text']),
          ),
        )
        .toList(growable: false);

    return UiParseResult.success(TaskListCardData(title: title, items: items));
  }
}

class PriceChartCardParser implements UiSchemaParser<PriceChartCardData> {
  const PriceChartCardParser();

  @override
  UiParseResult<PriceChartCardData> parse(Map<String, dynamic> raw) {
    final title = _asString(raw['title']);
    if (title == null) {
      return const UiParseResult.failure('price_chart 缺少 title');
    }

    final points = _asMapList(raw['points'])
        .map(
          (item) => PriceChartPoint(
            label: _asString(item['label']) ?? '-',
            value: _asDouble(item['value']) ?? 0,
          ),
        )
        .toList(growable: false);

    if (points.isEmpty) {
      return const UiParseResult.failure('price_chart 缺少 points');
    }

    return UiParseResult.success(
      PriceChartCardData(
        title: title,
        points: points,
        currencySymbol: _asString(raw['currency_symbol']) ?? '¥',
      ),
    );
  }
}

class UiComponentRegistry {
  const UiComponentRegistry();

  UiComponentData parse(Map<String, dynamic> raw) {
    final uiType = _asString(raw['ui_type']);
    final data = raw['data'];
    if (uiType == null) {
      return UnknownUiComponentData(
        uiTypeName: 'unknown',
        raw: raw,
        error: '缺少 ui_type',
      );
    }
    if (data is! Map<String, dynamic>) {
      return UnknownUiComponentData(
        uiTypeName: uiType,
        raw: raw,
        error: '缺少 data 或 data 不是对象',
      );
    }

    return switch (uiType) {
      'product_card' => _resolve(const ProductCardParser().parse(data), uiType, raw),
      'weather_card' => _resolve(const WeatherCardParser().parse(data), uiType, raw),
      'contact_card' => _resolve(const ContactCardParser().parse(data), uiType, raw),
      'calendar_event' =>
        _resolve(const CalendarEventCardParser().parse(data), uiType, raw),
      'map_preview' => _resolve(const MapPreviewCardParser().parse(data), uiType, raw),
      'train_card' => _resolve(const TrainCardParser().parse(data), uiType, raw),
      'flight_card' => _resolve(const FlightCardParser().parse(data), uiType, raw),
      'code_block' => _resolve(const CodeBlockCardParser().parse(data), uiType, raw),
      'task_list' => _resolve(const TaskListCardParser().parse(data), uiType, raw),
      'price_chart' => _resolve(const PriceChartCardParser().parse(data), uiType, raw),
      _ => UnknownUiComponentData(
        uiTypeName: uiType,
        raw: raw,
        error: '未注册的 ui_type',
      ),
    };
  }

  Widget build(BuildContext context, UiComponentData data) {
    return switch (data) {
      ProductCardData value => ProductCardWidget(card: value),
      WeatherCardData value => WeatherCardWidget(card: value),
      ContactCardData value => ContactCardWidget(card: value),
      CalendarEventCardData value => CalendarEventCardWidget(card: value),
      MapPreviewCardData value => MapPreviewCardWidget(card: value),
      TrainCardData value => TrainCardWidget(card: value),
      FlightCardData value => FlightCardWidget(card: value),
      CodeBlockCardData value => CodeBlockCardWidget(card: value),
      TaskListCardData value => TaskListCardWidget(card: value),
      PriceChartCardData value => PriceChartCardWidget(card: value),
      UnknownUiComponentData value => UnknownUiComponentWidget(card: value),
      _ => UnknownUiComponentWidget(
        card: UnknownUiComponentData(
          uiTypeName: data.uiType,
          raw: const <String, dynamic>{},
          error: '不支持的组件数据类型',
        ),
      ),
    };
  }

  UiComponentData _resolve<T extends UiComponentData>(
    UiParseResult<T> result,
    String uiType,
    Map<String, dynamic> raw,
  ) {
    if (result.data != null) {
      return result.data!;
    }
    return UnknownUiComponentData(
      uiTypeName: uiType,
      raw: raw,
      error: result.error ?? '解析失败',
    );
  }
}

String? tryEncodePrettyJson(Map<String, dynamic> raw) {
  try {
    return const JsonEncoder.withIndent('  ').convert(raw);
  } catch (_) {
    return null;
  }
}

String? _asString(Object? value) {
  return switch (value) {
    String item when item.trim().isNotEmpty => item.trim(),
    int item => item.toString(),
    double item => item.toString(),
    _ => null,
  };
}

double? _asDouble(Object? value) {
  return switch (value) {
    int item => item.toDouble(),
    double item => item,
    String item => double.tryParse(item),
    _ => null,
  };
}

int? _asInt(Object? value) {
  return switch (value) {
    int item => item,
    double item => item.toInt(),
    String item => int.tryParse(item),
    _ => null,
  };
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map(_asString).whereType<String>().toList(growable: false);
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

final uiComponentRegistryProvider = Provider<UiComponentRegistry>((ref) {
  return const UiComponentRegistry();
});

class UiCardShell extends StatelessWidget {
  const UiCardShell({
    super.key,
    required this.typeLabel,
    this.sourceLabel,
    required this.child,
    this.footer,
  });

  final String typeLabel;
  final String? sourceLabel;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = context.uiCardPadding;
    final maxWidth = context.uiCardMaxWidth;

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(typeLabel, style: theme.textTheme.titleMedium),
                ),
                if (sourceLabel != null)
                  Text(sourceLabel!, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
            if (footer != null) ...<Widget>[
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
    );

    if (maxWidth.isFinite) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: card,
        ),
      );
    }
    return card;
  }
}

class ProductCardWidget extends StatelessWidget {
  const ProductCardWidget({super.key, required this.card});

  final ProductCardData card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return UiCardShell(
      typeLabel: card.typeLabel,
      sourceLabel: '来自生成式 UI',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          OutlinedButton(onPressed: null, child: Text('比较价格')),
          OutlinedButton(onPressed: null, child: Text('查看详情')),
          FilledButton(onPressed: null, child: Text('告诉我更多')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.name, style: theme.textTheme.titleLarge),
          if (card.description != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(card.description!),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('¥${card.price.toStringAsFixed(card.price.truncateToDouble() == card.price ? 0 : 2)}'),
              if (card.originalPrice != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '¥${card.originalPrice!.toStringAsFixed(card.originalPrice!.truncateToDouble() == card.originalPrice ? 0 : 2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          if (card.rating != null || card.reviewCount != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('评分 ${card.rating?.toStringAsFixed(1) ?? '-'} · ${card.reviewCount ?? 0} 条评价'),
          ],
          if (card.highlights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: card.highlights
                  .map((item) => Chip(label: Text(item)))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class WeatherCardWidget extends StatelessWidget {
  const WeatherCardWidget({super.key, required this.card});

  final WeatherCardData card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.city}',
      sourceLabel: '来自生成式 UI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(card.temperature, style: theme.textTheme.headlineMedium),
              const SizedBox(width: 12),
              Expanded(child: Text(card.condition)),
            ],
          ),
          if (card.feelsLike != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('体感 ${card.feelsLike}'),
          ],
          if (card.forecast.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...card.forecast.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.day}  ${item.condition}  ${item.temperatureRange}${item.suggestion == null ? '' : '  ${item.suggestion}'}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactCardWidget extends StatelessWidget {
  const ContactCardWidget({super.key, required this.card});

  final ContactCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: card.typeLabel,
      sourceLabel: card.sourceLabel ?? '来自生成式 UI',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          OutlinedButton(onPressed: null, child: Text('拨打电话')),
          OutlinedButton(onPressed: null, child: Text('发送邮件')),
          FilledButton(onPressed: null, child: Text('发短信')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.name, style: Theme.of(context).textTheme.titleLarge),
          if (card.title != null || card.organization != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              [card.title, card.organization]
                  .whereType<String>()
                  .where((item) => item.trim().isNotEmpty)
                  .join(' · '),
            ),
          ],
          if (card.phone != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('📱 ${card.phone}'),
          ],
          if (card.email != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('📧 ${card.email}'),
          ],
        ],
      ),
    );
  }
}

class CalendarEventCardWidget extends StatelessWidget {
  const CalendarEventCardWidget({super.key, required this.card});

  final CalendarEventCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: card.typeLabel,
      sourceLabel: '来自生成式 UI',
      footer: Row(
        children: <Widget>[
          const OutlinedButton(onPressed: null, child: Text('修改详情')),
          const Spacer(),
          FilledButton(
            onPressed: null,
            child: Text(card.added ? '✅ 已添加' : '添加到日历'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('🗓️  ${card.dateText}'),
          const SizedBox(height: 4),
          Text('⏰  ${card.timeText}'),
          if (card.location != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('📍  ${card.location}'),
          ],
          if (card.reminder != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('🔔  ${card.reminder}'),
          ],
        ],
      ),
    );
  }
}

class MapPreviewCardWidget extends StatelessWidget {
  const MapPreviewCardWidget({super.key, required this.card});

  final MapPreviewCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: card.typeLabel,
      sourceLabel: '来自生成式 UI',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          OutlinedButton(onPressed: null, child: Text('高德地图')),
          OutlinedButton(onPressed: null, child: Text('百度地图')),
          FilledButton(onPressed: null, child: Text('步行导航')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: context.uiMapPreviewHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.map_outlined, size: 48),
          ),
          const SizedBox(height: 12),
          Text(card.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(card.routeText),
          if (card.durationText != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(card.durationText!),
          ],
          if (card.note != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(card.note!),
          ],
        ],
      ),
    );
  }
}

class TrainCardWidget extends StatelessWidget {
  const TrainCardWidget({super.key, required this.card});

  final TrainCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.trainNumber}',
      sourceLabel: card.seatType,
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          OutlinedButton(onPressed: null, child: Text('加入日历')),
          FilledButton(onPressed: null, child: Text('前往购票')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${card.departureStation} → ${card.arrivalStation}'),
          const SizedBox(height: 8),
          Text('${card.departureTime} - ${card.arrivalTime}'),
          if (card.duration != null || card.price != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              [card.duration, card.price]
                  .whereType<String>()
                  .where((item) => item.trim().isNotEmpty)
                  .join(' · '),
            ),
          ],
          if (card.dateText != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('📅 ${card.dateText}'),
          ],
          if (card.availability != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('💺 ${card.availability}'),
          ],
        ],
      ),
    );
  }
}

class FlightCardWidget extends StatelessWidget {
  const FlightCardWidget({super.key, required this.card});

  final FlightCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.flightNumber}',
      sourceLabel: card.status,
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          OutlinedButton(onPressed: null, child: Text('值机信息')),
          OutlinedButton(onPressed: null, child: Text('航班动态')),
          FilledButton(onPressed: null, child: Text('加入日历')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${card.departureAirport} → ${card.arrivalAirport}'),
          const SizedBox(height: 8),
          Text('${card.departureTime} - ${card.arrivalTime}'),
          if (card.duration != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(card.duration!),
          ],
          if (card.aircraft != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('机型 ${card.aircraft}'),
          ],
        ],
      ),
    );
  }
}

class CodeBlockCardWidget extends StatelessWidget {
  const CodeBlockCardWidget({super.key, required this.card});

  final CodeBlockCardData card;

  @override
  Widget build(BuildContext context) {
    return UiCardShell(
      typeLabel: card.typeLabel,
      sourceLabel: card.language,
      footer: Row(
        children: <Widget>[
          const OutlinedButton(onPressed: null, child: Text('复制')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: null,
            child: Text(card.canRun ? '运行' : '运行不可用'),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          card.code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class TaskListCardWidget extends StatelessWidget {
  const TaskListCardWidget({super.key, required this.card});

  final TaskListCardData card;

  @override
  Widget build(BuildContext context) {
    final completedCount = card.items.where((item) => item.completed).length;
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.title}',
      sourceLabel: '${card.items.length} 个任务 / $completedCount 已完成',
      footer: Row(
        children: <Widget>[
          const OutlinedButton(onPressed: null, child: Text('+ 添加任务')),
          const Spacer(),
          Text('${card.items.length} 个任务  $completedCount 已完成'),
        ],
      ),
      child: Column(
        children: card.items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        item.completed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    if (item.dueText != null) Text(item.dueText!),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class PriceChartCardWidget extends StatelessWidget {
  const PriceChartCardWidget({super.key, required this.card});

  final PriceChartCardData card;

  @override
  Widget build(BuildContext context) {
    final values = card.points.map((item) => item.value).toList(growable: false);
    final minValue = values.reduce((left, right) => left < right ? left : right);
    final maxValue = values.reduce((left, right) => left > right ? left : right);
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.title}',
      sourceLabel: '来自生成式 UI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: context.uiChartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _PriceChartPainter(
                points: card.points,
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('最低 ${card.currencySymbol}${minValue.toStringAsFixed(0)}'),
              const Spacer(),
              Text('最高 ${card.currencySymbol}${maxValue.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: card.points
                .map(
                  (item) => Text(
                    '${item.label} ${card.currencySymbol}${item.value.toStringAsFixed(0)}',
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  const _PriceChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<PriceChartPoint> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    const leftPadding = 8.0;
    const topPadding = 12.0;
    const rightPadding = 8.0;
    const bottomPadding = 24.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    for (var index = 0; index < 3; index += 1) {
      final y = topPadding + (chartHeight / 2) * index;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final min = points.map((item) => item.value).reduce((a, b) => a < b ? a : b);
    final max = points.map((item) => item.value).reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1 : max - min;

    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final x = leftPadding + (chartWidth * index / (points.length - 1 == 0 ? 1 : points.length - 1));
      final normalized = (point.value - min) / range;
      final y = topPadding + chartHeight - (normalized * chartHeight);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
    }
    canvas.drawPath(path, linePaint);

    final textStyle = TextStyle(color: gridColor, fontSize: 11);
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final x = leftPadding + (chartWidth * index / (points.length - 1 == 0 ? 1 : points.length - 1));
      final textPainter = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 48);
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class UnknownUiComponentWidget extends StatelessWidget {
  const UnknownUiComponentWidget({super.key, required this.card});

  final UnknownUiComponentData card;

  @override
  Widget build(BuildContext context) {
    final prettyJson = tryEncodePrettyJson(card.raw) ?? card.raw.toString();
    return UiCardShell(
      typeLabel: '${card.typeLabel} · ${card.uiTypeName}',
      sourceLabel: '降级展示',
      child: SelectionArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(card.error),
              const SizedBox(height: 8),
              Text(
                prettyJson,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
