import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/visual_camera_frame.dart';
import '../services/visual_platform_store.dart';
import '../utils/input_validation.dart';
import '../utils/shelf_counter.dart';

class VisualPlatformTile extends StatefulWidget {
  const VisualPlatformTile({super.key, required this.store});
  final VisualPlatformStore store;

  @override
  State<VisualPlatformTile> createState() => _VisualPlatformTileState();
}

class _VisualPlatformTileState extends State<VisualPlatformTile> {
  late Future<VisualPlatformData> _data = widget.store.load();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<VisualPlatformData>(
      future: _data,
      builder: (context, snapshot) {
        final stock = snapshot.data?.stock;
        final label = snapshot.data?.label;
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(
              l10n.visualPlatform,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text([
              if (label != null) label,
              if (stock != null)
                l10n.visualLastStock(_quantity(stock.estimate)),
              if (stock == null) l10n.visualTileHint,
            ].join('\n')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => VisualPlatformScreen(store: widget.store),
              ));
              if (mounted) setState(() => _data = widget.store.load());
            },
          ),
        );
      },
    );
  }
}

String _quantity(StockEstimate stock) =>
    '${stock.count}${stock.lowerBound ? '+' : ''}';

class VisualPlatformScreen extends StatefulWidget {
  const VisualPlatformScreen({super.key, required this.store});
  final VisualPlatformStore store;

  @override
  State<VisualPlatformScreen> createState() => _VisualPlatformScreenState();
}

enum _Stage { empty, one, ready }

class _VisualPlatformScreenState extends State<VisualPlatformScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _clock = Stopwatch()..start();
  CameraController? _camera;
  Future<void> _release = Future<void>.value();
  bool _loading = true, _opening = false, _closed = false;
  bool _active = true, _labelSaving = false, _calibrationSaving = false;
  bool _running = false, _expectHidden = false, _writing = false;
  int _generation = 0, _lastFrameTime = -1000;
  String? _cameraError, _source, _frameSource, _savedName;
  ShelfFrame? _draftEmpty, _frame;
  String? _draftSource;
  ShelfCounter? _counter;
  VisualStock? _stock;
  StockEstimate? _lastWritten;
  StableStockEstimate _stable = StableStockEstimate();
  _Stage _stage = _Stage.empty;
  bool _frameRejected = false, _saveError = false;
  String? _referenceError;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  bool get _safe => mounted && !_closed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await widget.store.load();
      if (!_safe) return;
      setState(() {
        _savedName = data.label;
        _name.text = data.label ?? '';
        _stock = data.stock;
        final empty = data.empty, one = data.oneItem;
        if (empty != null && one != null) {
          _counter = ShelfCounter.calibrate(empty, one);
          if (_counter != null) {
            _stage = _Stage.ready;
            _source = data.cameraKey;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (_safe) {
        setState(() {
          _loading = false;
          _saveError = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _active = false;
      // During the permission prompt there is no live frame yet. Let the
      // outstanding initialization finish and check lifecycle before streaming.
      if (!_opening) _closeCamera();
    }
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _closeCamera(refresh: false);
    _name.dispose();
    super.dispose();
  }

  void _closeCamera({bool refresh = true}) {
    final controller = _camera;
    _generation++;
    _camera = null;
    _opening = _running = _frameRejected = false;
    _frame = null;
    _frameSource = null;
    _stable = StableStockEstimate();
    if (controller != null) _release = _disposeCamera(controller);
    if (refresh && _safe) setState(() {});
  }

  Future<void> _disposeCamera(CameraController camera) async {
    try {
      await camera.dispose();
    } catch (_) {
      // The OS can revoke the session and release it before the app does.
    }
  }

  Future<void> _openCamera() async {
    if (_opening || _camera != null) return;
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        !(platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS)) {
      setState(() => _cameraError = 'unsupported');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _opening = true;
      _cameraError = null;
    });
    final generation = ++_generation;
    bool current() => _safe && _generation == generation;
    CameraController? controller;
    var opened = false;
    try {
      await _release;
      final cameras = await availableCameras();
      if (!current()) return;
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'unavailable');
        return;
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: platform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!current() || !_active) return;
      final live = controller;
      await live.startImageStream((image) => _onFrame(generation, live, image));
      if (!current() || !_active) return;
      opened = true;
      _lastFrameTime = -1000;
      setState(() => _camera = live);
    } on CameraException catch (e) {
      if (current()) setState(() => _cameraError = e.code);
    } catch (_) {
      if (current()) setState(() => _cameraError = 'unavailable');
    } finally {
      if (!opened && controller != null) await _disposeCamera(controller);
      if (current()) setState(() => _opening = false);
    }
  }

  void _onFrame(int generation, CameraController camera, CameraImage image) {
    if (!_safe || !_active || _generation != generation || _camera != camera) {
      return;
    }
    final now = _clock.elapsedMilliseconds;
    if (now - _lastFrameTime < 500) return;
    _lastFrameTime = now;
    ShelfFrame? frame;
    try {
      frame = sampleCameraFrame(image);
    } on RangeError {
      frame = null;
    }
    if (frame == null) {
      _closeCamera();
      setState(() => _cameraError = 'format');
      return;
    }
    final description = camera.description;
    final key = '${description.name}:${description.sensorOrientation}:'
        '${camera.value.deviceOrientation.name}:${image.width}x${image.height}';
    final changed = _frame == null || _frameSource != key;
    _frame = frame;
    _frameSource = key;
    if (_running) {
      if (_source != key) {
        setState(() {
          _running = false;
          _frameRejected = false;
        });
        return;
      }
      final result = _counter?.estimate(frame, expectHidden: _expectHidden);
      final rejected = result == null;
      if (rejected != _frameRejected) setState(() => _frameRejected = rejected);
      final stable = _stable.add(result);
      if (stable != null && stable != _lastWritten && !_writing) {
        unawaited(_record(stable));
      }
    } else if (changed) {
      setState(() {});
    }
  }

  Future<void> _saveName() async {
    if (!_form.currentState!.validate() || _labelSaving) return;
    final name = InputValidation.name(_name.text);
    FocusScope.of(context).unfocus();
    setState(() => _labelSaving = true);
    try {
      await widget.store.saveLabel(name);
      if (_safe) {
        setState(() {
          _savedName = name;
          _saveError = false;
        });
      }
    } catch (_) {
      if (_safe) setState(() => _saveError = true);
    } finally {
      if (_safe) setState(() => _labelSaving = false);
    }
  }

  void _beginCalibration() {
    setState(() {
      _draftEmpty = null;
      _draftSource = null;
      _stage = _Stage.empty;
      _running = _frameRejected = false;
      _referenceError = null;
    });
  }

  Future<void> _takeReference() async {
    final frame = _frame, source = _frameSource;
    if (frame == null || source == null || _calibrationSaving) return;
    if (_stage == _Stage.empty) {
      setState(() {
        _draftEmpty = frame;
        _draftSource = source;
        _stage = _Stage.one;
        _referenceError = null;
      });
      return;
    }
    if (_stage != _Stage.one) return;
    final empty = _draftEmpty;
    if (empty == null || source != _draftSource) {
      _beginCalibration();
      setState(() => _referenceError = 'position');
      return;
    }
    final counter = ShelfCounter.calibrate(empty, frame);
    if (counter == null) {
      setState(() => _referenceError = 'reference');
      return;
    }
    setState(() => _calibrationSaving = true);
    try {
      await widget.store.saveCalibration(source, empty, frame);
      if (_safe) {
        setState(() {
          _source = source;
          _counter = counter;
          _stage = _Stage.ready;
          _referenceError = null;
          _saveError = false;
        });
      }
    } catch (_) {
      if (_safe) setState(() => _saveError = true);
    } finally {
      if (_safe) setState(() => _calibrationSaving = false);
    }
  }

  void _toggleMeasurement() {
    if (_running) {
      setState(() => _running = _frameRejected = false);
      return;
    }
    if (_counter == null || _frame == null || _source != _frameSource) return;
    setState(() {
      _running = true;
      _frameRejected = _saveError = false;
      _lastWritten = null;
      _stable = StableStockEstimate();
    });
  }

  Future<void> _record(StockEstimate estimate) async {
    _writing = true;
    final stock = VisualStock(estimate, DateTime.now());
    try {
      await widget.store.saveStock(stock);
      if (_safe) {
        setState(() {
          _lastWritten = estimate;
          _stock = stock;
          _saveError = false;
        });
      }
    } catch (_) {
      if (_safe) {
        setState(() {
          _saveError = true;
          _running = _frameRejected = false;
        });
      }
    } finally {
      _writing = false;
    }
  }

  String _cameraErrorMessage(String error) {
    if (error == 'unsupported') return _l10n.visualMobileOnly;
    if (error.startsWith('CameraAccess')) return _l10n.visualPermission;
    if (error == 'format') return _l10n.visualCameraFormat;
    return _l10n.visualCameraUnavailable;
  }

  Widget _preview(CameraController camera) {
    final size = camera.value.previewSize!;
    final shortest = math.min(size.width, size.height);
    final longest = math.max(size.width, size.height);
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (context, constraints) {
          final portrait =
              MediaQuery.orientationOf(context) == Orientation.portrait;
          return Stack(fit: StackFit.expand, children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: portrait ? shortest : longest,
                height: portrait ? longest : shortest,
                child: CameraPreview(camera),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(4),
              child: IgnorePointer(
                  child: DecoratedBox(
                decoration: BoxDecoration(
                  border:
                      Border.fromBorderSide(BorderSide(color: Colors.white70)),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              )),
            ),
          ]);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final camera = _camera;
    final stock = _stock;
    final ready = _stage == _Stage.ready;
    final mismatch = ready && _frameSource != null && _frameSource != _source;
    final error = _cameraError;
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.visualPlatform)),
      body: _loading
          ? const LinearProgressIndicator()
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(
                          stock == null
                              ? l10n.visualNoStock
                              : l10n.visualLastStock(_quantity(stock.estimate)),
                        ),
                        subtitle: stock == null
                            ? Text(l10n.visualLocalStorage)
                            : Text([
                                localizations.formatShortDate(
                                    stock.measuredAt.toLocal()),
                                localizations.formatTimeOfDay(
                                    TimeOfDay.fromDateTime(
                                        stock.measuredAt.toLocal())),
                                if (stock.estimate.lowerBound)
                                  l10n.visualLowerBound,
                              ].join(' · ')),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(l10n.visualCamera,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(l10n.visualSetupHint),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(_cameraErrorMessage(error),
                            style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 12),
                      if (camera == null)
                        FilledButton.icon(
                          onPressed: _opening ? null : _openCamera,
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(_opening
                              ? l10n.visualCameraOpening
                              : l10n.visualCameraOpen),
                        )
                      else ...[
                        _preview(camera),
                        const SizedBox(height: 12),
                        if (ready) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.visualStacked),
                            subtitle: Text(l10n.visualStackedHint),
                            value: _expectHidden,
                            onChanged: (value) => setState(() {
                              _expectHidden = value;
                              _stable = StableStockEstimate();
                            }),
                          ),
                          if (mismatch)
                            Text(l10n.visualPositionError)
                          else if (_frameRejected)
                            Text(l10n.visualFrameRejected)
                          else if (_running)
                            Text(l10n.visualMeasuring)
                          else
                            Text(l10n.visualReady),
                          FilledButton.icon(
                            onPressed: _frame == null || mismatch
                                ? null
                                : _toggleMeasurement,
                            icon:
                                Icon(_running ? Icons.pause : Icons.play_arrow),
                            label: Text(_running
                                ? l10n.visualMeasurePause
                                : l10n.visualMeasureStart),
                          ),
                          TextButton(
                            onPressed:
                                _running || _writing ? null : _beginCalibration,
                            child: Text(l10n.visualRecalibrate),
                          ),
                        ] else ...[
                          Text(
                            _stage == _Stage.empty
                                ? l10n.visualEmptyStep
                                : l10n.visualOneStep,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(_stage == _Stage.empty
                              ? l10n.visualEmptyHint
                              : l10n.visualOneHint),
                          if (_referenceError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _referenceError == 'position'
                                    ? l10n.visualPositionError
                                    : l10n.visualReferenceError,
                                style:
                                    TextStyle(color: theme.colorScheme.error),
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _frame == null || _calibrationSaving
                                ? null
                                : _takeReference,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(l10n.visualCapture),
                          ),
                          if (_stage == _Stage.one)
                            TextButton(
                                onPressed: _calibrationSaving
                                    ? null
                                    : _beginCalibration,
                                child: Text(l10n.visualRecalibrate)),
                        ],
                        OutlinedButton(
                          onPressed: _calibrationSaving ? null : _closeCamera,
                          child: Text(l10n.visualCameraClose),
                        ),
                      ],
                      if (_saveError)
                        Text(l10n.visualSaveError,
                            style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Form(
                        key: _form,
                        child: TextFormField(
                          controller: _name,
                          maxLength: InputValidation.maxNameLength,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: l10n.visualLabel,
                            hintText: l10n.visualLabelHint,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) {
                            if (!_labelSaving) unawaited(_saveName());
                          },
                          validator: (value) {
                            try {
                              InputValidation.name(value ?? '');
                              return null;
                            } on ArgumentError {
                              return l10n.visualInvalidLabel;
                            }
                          },
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _labelSaving ||
                                _name.text.trim().isEmpty ||
                                _name.text.trim() == _savedName
                            ? null
                            : _saveName,
                        child: Text(l10n.visualSaveLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
