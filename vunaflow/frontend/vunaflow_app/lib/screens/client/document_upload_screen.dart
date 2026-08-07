import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String? loanId;
  const DocumentUploadScreen({super.key, this.loanId});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  bool _loading = true;
  List<dynamic> _documents = [];
  final Set<String> _uploading = {};

  final _docTypes = const [
    ('national_id', 'National ID', Icons.badge_outlined),
    ('title_deed', 'Title Deed', Icons.description_outlined),
    ('collateral', 'Collateral Document', Icons.inventory_2_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(
        '/api/documents/mine',
        query: widget.loanId != null ? {'loan_id': widget.loanId} : null,
      );
      setState(() => _documents = res as List<dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDocument(String filePath) async {
    final uri = Uri.parse(ApiConfig.fileUrl(filePath));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document')),
      );
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // required for Web
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    setState(() => _uploading.add(docType));

    try {
      if (pickedFile.bytes != null) {
        // Web / Byte array mode
        await ApiService.uploadFile(
          '/api/documents',
          bytes: pickedFile.bytes,
          filename: pickedFile.name,
          fields: {
            'doc_type': docType,
            if (widget.loanId != null) 'loan_id': widget.loanId!,
          },
        );
      } else if (pickedFile.path != null) {
        // Native File mode
        await ApiService.uploadFile(
          '/api/documents',
          file: File(pickedFile.path!),
          fields: {
            'doc_type': docType,
            if (widget.loanId != null) 'loan_id': widget.loanId!,
          },
        );
      } else {
        throw ApiException('Could not read file data');
      }

      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.shamba700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.goldPale, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Document uploaded successfully and saved to your file!',
                    style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.brick),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiService.delete('/api/documents/$id');
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document removed')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        title: Text(
          'Document Upload',
          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDocuments,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Upload the required verification documents for your AFC loan application.',
                        style: GoogleFonts.publicSans(fontSize: 16, color: AppColors.inkSoft, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      ..._docTypes.map((dt) {
                        final existing = _documents.where((d) => d['doc_type'] == dt.$1).toList();
                        final isUploading = _uploading.contains(dt.$1);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(34, 36, 30, 0.04),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                              BoxShadow(
                                color: Color.fromRGBO(34, 36, 30, 0.06),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.parchment2,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(dt.$3, color: AppColors.shamba700, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dt.$2,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        if (existing.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle, size: 14, color: AppColors.shamba700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Document uploaded & verified',
                                                  style: GoogleFonts.publicSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.shamba700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isUploading ? null : () => _pickAndUpload(dt.$1),
                                    icon: isUploading
                                        ? const SizedBox(
                                            height: 14,
                                            width: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                                          )
                                        : const Icon(Icons.upload_file, size: 18),
                                    label: Text(isUploading ? 'Uploading...' : 'Upload file'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: AppColors.ink,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                              if (existing.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(color: AppColors.line),
                                const SizedBox(height: 10),
                                ...existing.map((d) => Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.parchment,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppColors.shamba700),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  d['original_filename'] ?? 'Document file',
                                                  style: GoogleFonts.publicSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.ink,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Stored on AFC server',
                                                  style: GoogleFonts.ibmPlexMono(
                                                    fontSize: 11.5,
                                                    color: AppColors.inkFaint,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _openDocument(d['file_path']),
                                            icon: const Icon(Icons.open_in_new, size: 16),
                                            label: const Text('View'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.brick),
                                            onPressed: () => _delete(d['id']),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
