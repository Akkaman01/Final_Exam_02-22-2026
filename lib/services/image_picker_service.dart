import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService._();
  static final ImagePickerService instance = ImagePickerService._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return file?.path;
  }

  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.path;
  }
}
