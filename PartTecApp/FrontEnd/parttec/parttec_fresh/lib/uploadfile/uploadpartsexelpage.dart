import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:parttec/utils/app_settings.dart';
import 'package:parttec/utils/session_store.dart';

class UploadPartsExcelPage extends StatefulWidget {
  const UploadPartsExcelPage({super.key});

  @override
  State<UploadPartsExcelPage> createState() => _UploadPartsExcelPageState();
}

class _UploadPartsExcelPageState extends State<UploadPartsExcelPage> {
  String? selectedFile;
  File? pickedFile;
  bool isUploading = false;

Future<void> _pickExcelFile() async {
  try {
    // استدعاء مباشر بدون .platform واستخدام pickFile بدلاً من pickFiles
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    
    // التعامل المباشر مع خصائص الملف المُرجع
    if (file != null && file.path != null) {
      setState(() {
        pickedFile = File(file.path!);
        selectedFile = file.name;
      });
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ خطأ أثناء اختيار الملف: $e")),
    );
  }
}
  Future<void> _uploadExcelFile() async {
    if (pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء اختيار ملف Excel أولاً")),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final uri = Uri.parse("${AppSettings.serverurl}/part/upload-excel");

      var request = http.MultipartRequest("POST", uri);

      final userId = await SessionStore.userId();
      print("📌 UserId: $userId");
      request.fields["user"] = userId ?? "";

      request.files.add(
        await http.MultipartFile.fromPath("file", pickedFile!.path),
      );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم رفع الملف بنجاح")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ فشل رفع الملف: $resBody")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ خطأ: $e")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("رفع قطع (Excel)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("اختيار ملف Excel"),
              onPressed: _pickExcelFile,
            ),
            const SizedBox(height: 20),
            if (selectedFile != null)
              Text(
                "تم اختيار الملف: $selectedFile",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(isUploading ? "جاري الرفع..." : "رفع الملف"),
              onPressed: isUploading ? null : _uploadExcelFile,
            ),
          ],
        ),
      ),
    );
  }
}
