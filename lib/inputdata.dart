import 'package:flutter/material.dart';

void main() {
  runApp(const Inputdata());
}

class Inputdata extends StatelessWidget {
  const Inputdata({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coba-Coba Flutter',
      home: InputDataPelanggan(),
    );
  }
}

class InputDataPelanggan extends StatefulWidget {
  const InputDataPelanggan({super.key});

  @override
  State<InputDataPelanggan> createState() => _InputDataPelangganState();
}

class _InputDataPelangganState extends State<InputDataPelanggan> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers untuk text field
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nohpController = TextEditingController();
  final TextEditingController _merekModelController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  
  // Variabel untuk dropdown
  String? _jenisDevice;
  String? _serviceType;
  
  // List pilihan untuk dropdown
  final List<String> _jenisDeviceList = ['Laptop', 'PC', 'Smartphone', 'Tablet'];
  final List<String> _serviceTypeList = ['Instalasi', 'Perbaikan', 'Upgrade', 'Maintenance'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Input Data Pelanggan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nama Pelanggan
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama pelanggan harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 2. No. HP
              TextFormField(
                controller: _nohpController,
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'No. HP harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 3. Jenis Device (Dropdown)
              DropdownButtonFormField<String>(
                value: _jenisDevice,
                decoration: const InputDecoration(
                  labelText: 'Jenis Device',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices),
                ),
                items: _jenisDeviceList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _jenisDevice = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Jenis device harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 4. Merek & Model
              TextFormField(
                controller: _merekModelController,
                decoration: const InputDecoration(
                  labelText: 'Merek & Model',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smartphone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Merek & Model harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 5. Password Device
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password Device',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              // 6. Input Foto
              ElevatedButton.icon(
                onPressed: () {
                  // Fungsi untuk memilih foto
                  print('Pilih foto');
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Upload Foto Device'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),
              
              // 7. Service Type (Dropdown)
              DropdownButtonFormField<String>(
                value: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
                items: _serviceTypeList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _serviceType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Service type harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 8. Catatan
              TextFormField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              // Button Submit
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Proses data jika validasi berhasil
                    print('Nama: ${_namaController.text}');
                    print('No HP: ${_nohpController.text}');
                    print('Jenis Device: $_jenisDevice');
                    print('Merek & Model: ${_merekModelController.text}');
                    print('Password: ${_passwordController.text}');
                    print('Service Type: $_serviceType');
                    print('Catatan: ${_catatanController.text}');
                    
                    // Tampilkan pesan sukses
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data berhasil disimpan!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                ),
                child: const Text(
                  'SIMPAN DATA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _namaController.dispose();
    _nohpController.dispose();
    _merekModelController.dispose();
    _passwordController.dispose();
    _catatanController.dispose();
    super.dispose();
  }
}