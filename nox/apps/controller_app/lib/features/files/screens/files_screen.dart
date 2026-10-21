import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

enum _SortMode { newest, name, size }

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final _searchController = TextEditingController();
  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  _SortMode _sortMode = _SortMode.newest;
  String? _selectedDeviceId;

  final List<String> _filters = ['All', 'Images', 'Videos', 'Documents', 'Audio'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDevice(String? id) {
    setState(() {
      _selectedDeviceId = id;
      _searchController.clear();
      _searchQuery = '';
      _selectedFilter = 'All';
    });
  }

  void _cycleSort() {
    setState(() {
      _sortMode = _SortMode.values[(_sortMode.index + 1) % _SortMode.values.length];
    });
    final label = switch (_sortMode) {
      _SortMode.newest => 'newest first',
      _SortMode.name => 'name',
      _SortMode.size => 'size',
    };
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showNoxSnackBar(context, 'Sorted by $label');
  }

  List<_FileItem> _filtered(List<NoxFile> files) {
    var items = files.map(_FileItem.fromFile).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    if (_selectedFilter != 'All') {
      final wanted = switch (_selectedFilter) {
        'Images' => _FileType.image,
        'Videos' => _FileType.video,
        'Documents' => _FileType.document,
        'Audio' => _FileType.audio,
        _ => null,
      };
      items = items.where((f) => f.type == wanted).toList();
    }

    switch (_sortMode) {
      case _SortMode.newest:
        items.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case _SortMode.name:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortMode.size:
        items.sort((a, b) => b.bytes.compareTo(a.bytes));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull?.devices ?? const <Device>[];
    final selected = devices.where((d) => d.id == _selectedDeviceId).firstOrNull;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NoxColors.deepAbyss, NoxColors.voidBlack],
          ),
        ),
        child: SafeArea(
          child: selected == null
              ? _buildDevicePicker(devicesAsync)
              : _buildFilesBody(selected),
        ),
      ),
    );
  }

  // ── Device picker ──────────────────────────────────────────
  Widget _buildDevicePicker(AsyncValue<DevicesPage> devicesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, NoxSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Files', style: NoxTypography.h1),
              const SizedBox(height: 2),
              Text('Choose a device to browse its files', style: NoxTypography.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: NoxColors.lavenderPrimary,
            backgroundColor: NoxColors.darkSurface,
            onRefresh: () async {
              try {
                ref.invalidate(devicesProvider);
                await ref.read(devicesProvider.future);
              } catch (_) {}
            },
            child: devicesAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(
                child: NoxLoadingSpinner(message: 'Loading devices...'),
              ),
              error: (e, _) => NoxErrorState(
                message: 'Couldn\'t load devices',
                details: errorMessage(e),
                onRetry: () => ref.invalidate(devicesProvider),
              ),
              data: (page) {
                if (page.devices.isEmpty) {
                  return NoxEmptyState(
                    icon: Icons.devices_rounded,
                    title: 'No devices yet',
                    subtitle: 'Pair a device to browse its synced files.',
                    actionLabel: 'Add Device',
                    onAction: () => context.push('/add-device'),
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                  itemCount: page.devices.length,
                  itemBuilder: (context, index) {
                    final device = page.devices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: NoxSpacing.md),
                      child: NoxCard(
                        variant: NoxCardVariant.elevated,
                        padding: const EdgeInsets.all(NoxSpacing.lg),
                        onTap: () => _selectDevice(device.id),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: NoxColors.cardGradient,
                                borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
                                border: Border.all(color: NoxColors.glassBorder, width: 0.5),
                              ),
                              child: Center(
                                child: Icon(deviceIcon(device),
                                    size: 22, color: NoxColors.lavenderLight),
                              ),
                            ),
                            const SizedBox(width: NoxSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    style: NoxTypography.subtitle.copyWith(
                                      color: NoxColors.pureWhite,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(device.typeDescription, style: NoxTypography.caption),
                                ],
                              ),
                            ),
                            NoxStatusDot(status: deviceStatus(device)),
                            const SizedBox(width: NoxSpacing.sm),
                            const Icon(Icons.chevron_right_rounded,
                                color: NoxColors.dimGray, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Files for selected device ──────────────────────────────
  Widget _buildFilesBody(Device device) {
    final provider = deviceFilesProvider(device.id);
    final filesAsync = ref.watch(provider);
    final allFiles = filesAsync.valueOrNull ?? const <NoxFile>[];
    final files = _filtered(allFiles);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0,
          ),
          child: _buildHeader(allFiles),
        ),

        // Breadcrumb (current device — tap to switch)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NoxSpacing.xxl, NoxSpacing.md, NoxSpacing.xxl, 0,
          ),
          child: _buildBreadcrumb(device),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.all(NoxSpacing.xxl),
          child: NoxTextField(
            hint: 'Search files...',
            controller: _searchController,
            leadingIcon: Icons.search_rounded,
            onChanged: (value) => setState(() => _searchQuery = value),
            trailing: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(
                      Icons.clear_rounded, size: 18,
                      color: NoxColors.mistGray,
                    ),
                  )
                : null,
          ),
        ),

        // Filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: NoxSpacing.sm),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = filter == _selectedFilter;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: NoxSpacing.lg,
                    vertical: NoxSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NoxColors.lavenderPrimary.withValues(alpha: 0.15)
                        : NoxColors.glassWhite,
                    borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
                    border: Border.all(
                      color: isSelected
                          ? NoxColors.lavenderPrimary.withValues(alpha: 0.4)
                          : NoxColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: NoxTypography.bodySmall.copyWith(
                      color: isSelected
                          ? NoxColors.lavenderLight
                          : NoxColors.mistGray,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: NoxSpacing.lg),

        // File list/grid
        Expanded(
          child: RefreshIndicator(
            color: NoxColors.lavenderPrimary,
            backgroundColor: NoxColors.darkSurface,
            onRefresh: () async {
              try {
                ref.invalidate(provider);
                await ref.read(provider.future);
              } catch (_) {}
            },
            child: filesAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading files...')),
              error: (e, _) => NoxErrorState(
                message: 'Couldn\'t load files',
                details: errorMessage(e),
                onRetry: () => ref.invalidate(provider),
              ),
              data: (_) => files.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                      ? _buildGridView(files)
                      : _buildListView(files),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<NoxFile> allFiles) {
    final totalBytes = allFiles.fold<int>(0, (sum, f) => sum + f.size);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Files', style: NoxTypography.h1),
            const SizedBox(height: 2),
            Text(
              '${allFiles.length} item${allFiles.length == 1 ? '' : 's'} • ${formatBytes(totalBytes)}',
              style: NoxTypography.bodySmall,
            ),
          ],
        ),
        Row(
          children: [
            NoxIconButton(
              icon: _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              onPressed: () => setState(() => _isGridView = !_isGridView),
              size: 40,
              tooltip: _isGridView ? 'List view' : 'Grid view',
            ),
            const SizedBox(width: NoxSpacing.sm),
            NoxIconButton(
              icon: Icons.sort_rounded,
              onPressed: _cycleSort,
              size: 40,
              tooltip: 'Sort',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(Device device) {
    return GestureDetector(
      onTap: () => _selectDevice(null),
      child: Row(
        children: [
          Icon(
            deviceIcon(device),
            size: 16,
            color: NoxColors.lavenderLight,
          ),
          const SizedBox(width: NoxSpacing.xs),
          Flexible(
            child: Text(
              device.name,
              style: NoxTypography.bodySmall.copyWith(
                color: NoxColors.lavenderLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: NoxSpacing.sm),
          Text(
            'Change',
            style: NoxTypography.caption.copyWith(
              color: NoxColors.mistGray,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return NoxEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No files found',
        subtitle: 'No files match "$_searchQuery"',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }

    return const NoxEmptyState(
      icon: Icons.folder_open_rounded,
      title: 'No files here',
      subtitle: 'Files will appear once this device syncs its data.',
    );
  }

  Widget _buildGridView(List<_FileItem> files) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: NoxSpacing.md,
        crossAxisSpacing: NoxSpacing.md,
        childAspectRatio: 1.1,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return NoxCard(
          variant: NoxCardVariant.elevated,
          padding: const EdgeInsets.all(NoxSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: file.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
                ),
                child: Center(
                  child: Icon(file.icon, size: 26, color: file.color),
                ),
              ),
              const SizedBox(height: NoxSpacing.md),
              Text(
                file.name,
                style: NoxTypography.subtitle.copyWith(
                  color: NoxColors.softWhite,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: NoxSpacing.xs),
              Text(
                file.size,
                style: NoxTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(List<_FileItem> files) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: NoxSpacing.sm),
          child: NoxCard(
            variant: NoxCardVariant.glass,
            padding: const EdgeInsets.all(NoxSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: file.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
                  ),
                  child: Center(
                    child: Icon(file.icon, size: 22, color: file.color),
                  ),
                ),
                const SizedBox(width: NoxSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: NoxTypography.subtitle.copyWith(
                          color: NoxColors.softWhite,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${file.size} • ${file.modified}',
                        style: NoxTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _FileType { image, video, document, audio, other }

class _FileItem {
  final String name;
  final _FileType type;
  final String size;
  final int bytes;
  final String modified;
  final DateTime? createdAt;
  final IconData icon;
  final Color color;

  const _FileItem({
    required this.name,
    required this.type,
    required this.size,
    required this.bytes,
    required this.modified,
    required this.createdAt,
    required this.icon,
    required this.color,
  });

  factory _FileItem.fromFile(NoxFile f) {
    final mime = f.mimeType;
    final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';

    final (_FileType type, IconData icon, Color color) = switch (mime) {
      _ when mime.startsWith('image/') =>
        (_FileType.image, Icons.image_rounded, NoxColors.peachAccent),
      _ when mime.startsWith('video/') =>
        (_FileType.video, Icons.video_file_rounded, NoxColors.pinkSoft),
      _ when mime.startsWith('audio/') =>
        (_FileType.audio, Icons.audio_file_rounded, NoxColors.icyBlue),
      _ when mime == 'application/pdf' =>
        (_FileType.document, Icons.picture_as_pdf_rounded, NoxColors.offlineRed),
      _ when mime.contains('presentation') || ext == 'ppt' || ext == 'pptx' =>
        (_FileType.document, Icons.slideshow_rounded, NoxColors.peachAccent),
      _ when mime.contains('spreadsheet') || mime.contains('csv') || ext == 'xlsx' =>
        (_FileType.document, Icons.table_chart_rounded, NoxColors.onlineGreen),
      _ when mime.startsWith('text/') || mime.contains('document') || mime.contains('msword') =>
        (_FileType.document, Icons.description_rounded, NoxColors.lavenderPrimary),
      _ => (_FileType.other, Icons.insert_drive_file_rounded, NoxColors.mistGray),
    };

    return _FileItem(
      name: f.name,
      type: type,
      size: formatBytes(f.size),
      bytes: f.size,
      modified: timeAgo(f.createdAt),
      createdAt: f.createdAt,
      icon: icon,
      color: color,
    );
  }
}
