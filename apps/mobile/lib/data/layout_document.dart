import 'dart:convert';
import 'dart:ui' show Rect;

/// The overall nature of the PDF document.
enum DocumentType {
  digital,
  scanned,
  mixed,
  unknown;

  static DocumentType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'digital':
        return DocumentType.digital;
      case 'scanned':
        return DocumentType.scanned;
      case 'mixed':
        return DocumentType.mixed;
      default:
        return DocumentType.unknown;
    }
  }
}

/// Lifecycle status of the conversion workflow.
enum ConversionStatus {
  imported,
  classified,
  translating,
  translated,
  fitting,
  rendering,
  completed,
  failed;

  static ConversionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'imported':
        return ConversionStatus.imported;
      case 'classified':
        return ConversionStatus.classified;
      case 'translating':
        return ConversionStatus.translating;
      case 'translated':
        return ConversionStatus.translated;
      case 'fitting':
        return ConversionStatus.fitting;
      case 'rendering':
        return ConversionStatus.rendering;
      case 'completed':
        return ConversionStatus.completed;
      case 'failed':
        return ConversionStatus.failed;
      default:
        return ConversionStatus.imported;
    }
  }
}

/// The extraction classification of an individual page.
enum PageType {
  digital,
  scanned,
  mixed;

  static PageType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'digital':
        return PageType.digital;
      case 'scanned':
        return PageType.scanned;
      case 'mixed':
        return PageType.mixed;
      default:
        return PageType.scanned;
    }
  }
}

/// Processing status of an individual page.
enum PageConversionStatus {
  pending,
  extracted,
  translated,
  reconstructed,
  failed,
  requiresManualReview;

  static PageConversionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'pending':
        return PageConversionStatus.pending;
      case 'extracted':
        return PageConversionStatus.extracted;
      case 'translated':
        return PageConversionStatus.translated;
      case 'reconstructed':
        return PageConversionStatus.reconstructed;
      case 'failed':
        return PageConversionStatus.failed;
      case 'requiresmanualreview':
        return PageConversionStatus.requiresManualReview;
      default:
        return PageConversionStatus.pending;
    }
  }
}

/// Supported semantic and layout region categories.
enum RegionType {
  heading,
  paragraph,
  table,
  tableCell,
  list,
  listItem,
  header,
  footer,
  image,
  caption,
  pageNumber,
  formula,
  unknown;

  static RegionType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'heading':
        return RegionType.heading;
      case 'paragraph':
        return RegionType.paragraph;
      case 'table':
        return RegionType.table;
      case 'tablecell':
        return RegionType.tableCell;
      case 'list':
        return RegionType.list;
      case 'listitem':
        return RegionType.listItem;
      case 'header':
        return RegionType.header;
      case 'footer':
        return RegionType.footer;
      case 'image':
        return RegionType.image;
      case 'caption':
        return RegionType.caption;
      case 'pagenumber':
        return RegionType.pageNumber;
      case 'formula':
        return RegionType.formula;
      default:
        return RegionType.unknown;
    }
  }
}

/// Text alignment within the bounding region.
enum TextAlignment {
  left,
  center,
  right,
  justify;

  static TextAlignment fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'center':
        return TextAlignment.center;
      case 'right':
        return TextAlignment.right;
      case 'justify':
        return TextAlignment.justify;
      case 'left':
      default:
        return TextAlignment.left;
    }
  }
}

/// Translation lifecycle of an individual region.
enum RegionTranslationStatus {
  untranslated,
  inProgress,
  translated,
  failed,
  manuallyEdited;

  static RegionTranslationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'inprogress':
        return RegionTranslationStatus.inProgress;
      case 'translated':
        return RegionTranslationStatus.translated;
      case 'failed':
        return RegionTranslationStatus.failed;
      case 'manuallyedited':
        return RegionTranslationStatus.manuallyEdited;
      case 'untranslated':
      default:
        return RegionTranslationStatus.untranslated;
    }
  }
}

/// Rendering and layout status of an individual region in the final output.
enum RenderingStatus {
  original,
  facsimileMasked,
  reflowed,
  overflowed,
  manualReviewRecommended;

  static RenderingStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'facsimilemasked':
        return RenderingStatus.facsimileMasked;
      case 'reflowed':
        return RenderingStatus.reflowed;
      case 'overflowed':
        return RenderingStatus.overflowed;
      case 'manualreviewrecommended':
        return RenderingStatus.manualReviewRecommended;
      case 'original':
      default:
        return RenderingStatus.original;
    }
  }
}

/// Spatial bounding rectangle in PDF point coordinates (72 points per inch, origin top-left).
class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + (width / 2.0);
  double get centerY => y + (height / 2.0);
  double get area => width * height;

  bool get isEmpty => width <= 0.0 || height <= 0.0;

  Rect toRect() => Rect.fromLTWH(x, y, width, height);

  static BoundingBox fromRect(Rect rect) => BoundingBox(
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      );

  bool intersects(BoundingBox other) {
    return x < other.right &&
        right > other.x &&
        y < other.bottom &&
        bottom > other.y;
  }

  bool contains(BoundingBox other) {
    return x <= other.x &&
        y <= other.y &&
        right >= other.right &&
        bottom >= other.bottom;
  }

  BoundingBox union(BoundingBox other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    final minX = x < other.x ? x : other.x;
    final minY = y < other.y ? y : other.y;
    final maxX = right > other.right ? right : other.right;
    final maxY = bottom > other.bottom ? bottom : other.bottom;
    return BoundingBox(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Converts this bounding box from PDF points to normalized [0.0 - 1.0] coordinates.
  BoundingBox toNormalized({required double pageWidth, required double pageHeight}) {
    if (pageWidth <= 0 || pageHeight <= 0) return this;
    return BoundingBox(
      x: (x / pageWidth).clamp(0.0, 1.0),
      y: (y / pageHeight).clamp(0.0, 1.0),
      width: (width / pageWidth).clamp(0.0, 1.0),
      height: (height / pageHeight).clamp(0.0, 1.0),
    );
  }

  /// Converts normalized coordinates [0.0 - 1.0] to PDF points given page dimensions.
  static BoundingBox fromNormalized({
    required BoundingBox normalized,
    required double pageWidth,
    required double pageHeight,
  }) {
    return BoundingBox(
      x: normalized.x * pageWidth,
      y: normalized.y * pageHeight,
      width: normalized.width * pageWidth,
      height: normalized.height * pageHeight,
    );
  }

  /// Converts PDF points (72 DPI) to raster pixel coordinates at a given target DPI.
  BoundingBox toPixel({required double targetDpi, double baseDpi = 72.0}) {
    final scale = targetDpi / baseDpi;
    return BoundingBox(
      x: x * scale,
      y: y * scale,
      width: width * scale,
      height: height * scale,
    );
  }

  /// Converts raster pixel coordinates at [sourceDpi] to PDF points (72 DPI).
  static BoundingBox fromPixel({
    required BoundingBox pixelBox,
    required double sourceDpi,
    double baseDpi = 72.0,
  }) {
    final scale = baseDpi / sourceDpi;
    return BoundingBox(
      x: pixelBox.x * scale,
      y: pixelBox.y * scale,
      width: pixelBox.width * scale,
      height: pixelBox.height * scale,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        width: (json['width'] as num?)?.toDouble() ?? 0.0,
        height: (json['height'] as num?)?.toDouble() ?? 0.0,
      );

  BoundingBox copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      BoundingBox(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  String toString() =>
      'BoundingBox(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, w: ${width.toStringAsFixed(1)}, h: ${height.toStringAsFixed(1)})';
}

/// Typographic properties for rendering Ol Chiki text.
class FontSpec {
  const FontSpec({
    this.fontFamily = 'NotoSansOlChiki',
    this.fontSize = 11.0,
    this.isBold = false,
    this.isItalic = false,
    this.textColor = 0xFF000000,
    this.backgroundColor,
  });

  final String fontFamily;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final int textColor;
  final int? backgroundColor;

  FontSpec copyWith({
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    int? textColor,
    int? backgroundColor,
  }) =>
      FontSpec(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        isBold: isBold ?? this.isBold,
        isItalic: isItalic ?? this.isItalic,
        textColor: textColor ?? this.textColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'isBold': isBold,
        'isItalic': isItalic,
        'textColor': textColor,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
      };

  factory FontSpec.fromJson(Map<String, dynamic> json) => FontSpec(
        fontFamily: json['fontFamily'] as String? ?? 'NotoSansOlChiki',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 11.0,
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        textColor: json['textColor'] as int? ?? 0xFF000000,
        backgroundColor: json['backgroundColor'] as int?,
      );
}

/// A distinct semantic or visual block on a page.
class LayoutRegion {
  LayoutRegion({
    required this.regionId,
    required this.type,
    required this.originalText,
    this.translatedText = '',
    required this.boundingBox,
    this.fontSpec = const FontSpec(),
    this.alignment = TextAlignment.left,
    required this.readingOrder,
    this.ocrConfidence,
    this.children = const [],
    this.translationStatus = RegionTranslationStatus.untranslated,
    this.renderingStatus = RenderingStatus.original,
    this.diagnosticNote,
    this.customMetadata = const {},
  });

  final String regionId;
  final RegionType type;
  String originalText;
  String translatedText;
  BoundingBox boundingBox;
  FontSpec fontSpec;
  TextAlignment alignment;
  int readingOrder;
  double? ocrConfidence;
  List<LayoutRegion> children;
  RegionTranslationStatus translationStatus;
  RenderingStatus renderingStatus;
  String? diagnosticNote;
  Map<String, dynamic> customMetadata;

  bool get isTable => type == RegionType.table;
  bool get isHeading => type == RegionType.heading;
  bool get isList => type == RegionType.list || type == RegionType.listItem;
  bool get hasContinuation => customMetadata['hasContinuation'] == true;
  bool get isContinuation => customMetadata['isContinuation'] == true;
  bool get hasComplexBackground => customMetadata['hasComplexBackground'] == true;
  String? get restorationConfidence => customMetadata['restorationConfidence'] as String?;

  LayoutRegion copyWith({
    String? regionId,
    RegionType? type,
    String? originalText,
    String? translatedText,
    BoundingBox? boundingBox,
    FontSpec? fontSpec,
    TextAlignment? alignment,
    int? readingOrder,
    double? ocrConfidence,
    List<LayoutRegion>? children,
    RegionTranslationStatus? translationStatus,
    RenderingStatus? renderingStatus,
    String? diagnosticNote,
    Map<String, dynamic>? customMetadata,
  }) {
    return LayoutRegion(
      regionId: regionId ?? this.regionId,
      type: type ?? this.type,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      boundingBox: boundingBox ?? this.boundingBox,
      fontSpec: fontSpec ?? this.fontSpec,
      alignment: alignment ?? this.alignment,
      readingOrder: readingOrder ?? this.readingOrder,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      children: children ?? this.children,
      translationStatus: translationStatus ?? this.translationStatus,
      renderingStatus: renderingStatus ?? this.renderingStatus,
      diagnosticNote: diagnosticNote ?? this.diagnosticNote,
      customMetadata: customMetadata ?? this.customMetadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'regionId': regionId,
        'type': type.name,
        'originalText': originalText,
        'translatedText': translatedText,
        'boundingBox': boundingBox.toJson(),
        'fontSpec': fontSpec.toJson(),
        'alignment': alignment.name,
        'readingOrder': readingOrder,
        if (ocrConfidence != null) 'ocrConfidence': ocrConfidence,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
        'translationStatus': translationStatus.name,
        'renderingStatus': renderingStatus.name,
        if (diagnosticNote != null) 'diagnosticNote': diagnosticNote,
        if (customMetadata.isNotEmpty) 'customMetadata': customMetadata,
      };

  factory LayoutRegion.fromJson(Map<String, dynamic> json) {
    return LayoutRegion(
      regionId: json['regionId'] as String? ?? '',
      type: RegionType.fromString(json['type'] as String?),
      originalText: json['originalText'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
      boundingBox: BoundingBox.fromJson(
          json['boundingBox'] as Map<String, dynamic>? ?? {}),
      fontSpec: FontSpec.fromJson(
          json['fontSpec'] as Map<String, dynamic>? ?? {}),
      alignment: TextAlignment.fromString(json['alignment'] as String?),
      readingOrder: json['readingOrder'] as int? ?? 0,
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => LayoutRegion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translationStatus:
          RegionTranslationStatus.fromString(json['translationStatus'] as String?),
      renderingStatus:
          RenderingStatus.fromString(json['renderingStatus'] as String?),
      diagnosticNote: json['diagnosticNote'] as String?,
      customMetadata:
          json['customMetadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}

/// An individual document page preserving dimensions, page type, background, and regions.
class LayoutPage {
  LayoutPage({
    required this.pageNumber,
    required this.width,
    required this.height,
    this.rotation = 0,
    required this.pageType,
    this.backgroundImagePath,
    required this.regions,
    this.status = PageConversionStatus.pending,
    this.pageRenderingMetadata = const {},
  });

  final int pageNumber;
  final double width; // in PDF points (72 pt/in, A4 = 595.28)
  final double height; // in PDF points (72 pt/in, A4 = 841.89)
  final int rotation; // 0, 90, 180, 270
  final PageType pageType;
  String? backgroundImagePath;
  List<LayoutRegion> regions;
  PageConversionStatus status;
  Map<String, dynamic> pageRenderingMetadata;

  int get totalRegions => regions.length;
  int get translatedRegions => regions
      .where((r) =>
          r.translationStatus == RegionTranslationStatus.translated ||
          r.translationStatus == RegionTranslationStatus.manuallyEdited)
      .length;

  bool get isDigital => pageType == PageType.digital;
  bool get isScanned => pageType == PageType.scanned;
  bool get isContinuationPage => pageRenderingMetadata['isContinuationPage'] == true;

  LayoutPage copyWith({
    int? pageNumber,
    double? width,
    double? height,
    int? rotation,
    PageType? pageType,
    String? backgroundImagePath,
    List<LayoutRegion>? regions,
    PageConversionStatus? status,
    Map<String, dynamic>? pageRenderingMetadata,
  }) {
    return LayoutPage(
      pageNumber: pageNumber ?? this.pageNumber,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      pageType: pageType ?? this.pageType,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      regions: regions ?? this.regions,
      status: status ?? this.status,
      pageRenderingMetadata:
          pageRenderingMetadata ?? this.pageRenderingMetadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'width': width,
        'height': height,
        'rotation': rotation,
        'pageType': pageType.name,
        if (backgroundImagePath != null)
          'backgroundImagePath': backgroundImagePath,
        'regions': regions.map((r) => r.toJson()).toList(),
        'status': status.name,
        if (pageRenderingMetadata.isNotEmpty)
          'pageRenderingMetadata': pageRenderingMetadata,
      };

  factory LayoutPage.fromJson(Map<String, dynamic> json) {
    return LayoutPage(
      pageNumber: json['pageNumber'] as int? ?? 1,
      width: (json['width'] as num?)?.toDouble() ?? 595.28,
      height: (json['height'] as num?)?.toDouble() ?? 841.89,
      rotation: json['rotation'] as int? ?? 0,
      pageType: PageType.fromString(json['pageType'] as String?),
      backgroundImagePath: json['backgroundImagePath'] as String?,
      regions: (json['regions'] as List<dynamic>?)
              ?.map((e) => LayoutRegion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: PageConversionStatus.fromString(json['status'] as String?),
      pageRenderingMetadata:
          json['pageRenderingMetadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}

/// The unified multi-page document model for AnuvaadAI 2.0.
class LayoutDocument {
  LayoutDocument({
    required this.documentId,
    required this.sourceFileName,
    this.sourceLanguage = 'hin_Deva',
    this.targetLanguage = 'sat_Olck',
    required this.pageCount,
    required this.documentType,
    this.conversionStatus = ConversionStatus.imported,
    DateTime? createdAt,
    required this.pages,
    required this.sourceFilePath,
    this.outputFilePath,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  final String documentId;
  final String sourceFileName;
  final String sourceLanguage;
  final String targetLanguage;
  final int pageCount;
  final DocumentType documentType;
  ConversionStatus conversionStatus;
  final DateTime createdAt;
  List<LayoutPage> pages;
  final String sourceFilePath;
  String? outputFilePath;
  Map<String, dynamic> metadata;

  int get totalRegions =>
      pages.fold<int>(0, (sum, page) => sum + page.totalRegions);

  int get translatedRegions =>
      pages.fold<int>(0, (sum, page) => sum + page.translatedRegions);

  double get translationProgress =>
      totalRegions > 0 ? (translatedRegions / totalRegions) : 0.0;

  int get digitalPageCount =>
      pages.where((p) => p.pageType == PageType.digital).length;

  int get scannedPageCount =>
      pages.where((p) => p.pageType == PageType.scanned).length;

  int get mixedPageCount =>
      pages.where((p) => p.pageType == PageType.mixed).length;

  LayoutDocument copyWith({
    String? documentId,
    String? sourceFileName,
    String? sourceLanguage,
    String? targetLanguage,
    int? pageCount,
    DocumentType? documentType,
    ConversionStatus? conversionStatus,
    DateTime? createdAt,
    List<LayoutPage>? pages,
    String? sourceFilePath,
    String? outputFilePath,
    Map<String, dynamic>? metadata,
  }) {
    return LayoutDocument(
      documentId: documentId ?? this.documentId,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      pageCount: pageCount ?? this.pageCount,
      documentType: documentType ?? this.documentType,
      conversionStatus: conversionStatus ?? this.conversionStatus,
      createdAt: createdAt ?? this.createdAt,
      pages: pages ?? this.pages,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'sourceFileName': sourceFileName,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'pageCount': pageCount,
        'documentType': documentType.name,
        'conversionStatus': conversionStatus.name,
        'createdAt': createdAt.toIso8601String(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'sourceFilePath': sourceFilePath,
        if (outputFilePath != null) 'outputFilePath': outputFilePath,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory LayoutDocument.fromJson(Map<String, dynamic> json) {
    return LayoutDocument(
      documentId: json['documentId'] as String? ?? '',
      sourceFileName: json['sourceFileName'] as String? ?? '',
      sourceLanguage: json['sourceLanguage'] as String? ?? 'hin_Deva',
      targetLanguage: json['targetLanguage'] as String? ?? 'sat_Olck',
      pageCount: json['pageCount'] as int? ?? 0,
      documentType: DocumentType.fromString(json['documentType'] as String?),
      conversionStatus:
          ConversionStatus.fromString(json['conversionStatus'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      pages: (json['pages'] as List<dynamic>?)
              ?.map((e) => LayoutPage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sourceFilePath: json['sourceFilePath'] as String? ?? '',
      outputFilePath: json['outputFilePath'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LayoutDocument.fromJsonString(String str) =>
      LayoutDocument.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
