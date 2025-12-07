import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PartnerFormPage extends StatefulWidget {
  const PartnerFormPage({Key? key}) : super(key: key);

  @override
  _PartnerFormPageState createState() => _PartnerFormPageState();
}

class _PartnerFormPageState extends State<PartnerFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _emailController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _domainController = TextEditingController();
  final _phoneController = TextEditingController();
  final _physicalAddressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Service type checkboxes
  Map<String, bool> _serviceTypes = {
    "Vet": false,
    "Boarding": false,
    "Buy/Sell": false,
    "Grooming": false,
    "Mortuary": false,
    "Pet Shop Items": false,
  };

  bool _isAvailable24x7 = false;
  bool _hasEmergencyServices = false;

  // New state variable to track submission progress.
  bool _isSubmitting = false;

  /// Helper for text fields that adjusts font size based on screen width.
  Widget _buildTextField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        required String validatorMessage,
        required IconData icon,
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    double fieldFontSize;
    if (screenWidth < 400) {
      fieldFontSize = 12; // Very narrow screens
    } else if (screenWidth < 600) {
      fieldFontSize = 14; // Mid-range screens
    } else {
      fieldFontSize = 16; // Normal size on wider screens
    }

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: fieldFontSize),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[600], size: fieldFontSize + 4),
        labelText: label,
        hintText: 'Enter $label',
        labelStyle: TextStyle(fontSize: fieldFontSize),
        hintStyle: TextStyle(fontSize: fieldFontSize),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff2575FC), width: 2.0),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return validatorMessage;
        return null;
      },
    );
  }

  /// Build service types checkboxes.
  Widget _buildServiceTypes() {
    List<Widget> checkboxes = [];
    _serviceTypes.forEach((key, value) {
      checkboxes.add(
        CheckboxListTile(
          title: Text(key),
          value: value,
          onChanged: (bool? newVal) {
            setState(() {
              _serviceTypes[key] = newVal ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: checkboxes,
    );
  }

  /// Builds the responsive form layout.
  Widget _buildResponsiveForm(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        if (isWide) {
          // Two-column layout
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  children: [
                    _buildTextField(
                      context,
                      controller: _emailController,
                      label: 'Email',
                      validatorMessage: 'Please enter your email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _businessNameController,
                      label: 'Business/Company Name',
                      validatorMessage: 'Please enter your business/company name',
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _domainController,
                      label: 'Domain of Work',
                      validatorMessage: 'Please enter your domain of work',
                      icon: Icons.work,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _phoneController,
                      label: 'Phone Number',
                      validatorMessage: 'Please enter your phone number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _physicalAddressController,
                      label: 'Physical Address',
                      validatorMessage: 'Please enter your address',
                      icon: Icons.location_on,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _websiteController,
                      label: 'Website/Social Media',
                      validatorMessage: 'Please enter your website or social media link',
                      icon: Icons.link,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      context,
                      controller: _descriptionController,
                      label: 'Description',
                      validatorMessage: 'Please describe what you do',
                      icon: Icons.description,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Types',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    _buildServiceTypes(),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('24/7 Availability'),
                      value: _isAvailable24x7,
                      onChanged: (bool? newVal) {
                        setState(() {
                          _isAvailable24x7 = newVal ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('Emergency Services'),
                      value: _hasEmergencyServices,
                      onChanged: (bool? newVal) {
                        setState(() {
                          _hasEmergencyServices = newVal ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Single-column layout for narrow screens
          return Column(
            children: [
              _buildTextField(
                context,
                controller: _emailController,
                label: 'Email',
                validatorMessage: 'Please enter your email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _businessNameController,
                label: 'Business/Company Name',
                validatorMessage: 'Please enter your business/company name',
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _domainController,
                label: 'Domain of Work',
                validatorMessage: 'Please enter your domain of work',
                icon: Icons.work,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _phoneController,
                label: 'Phone Number',
                validatorMessage: 'Please enter your phone number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _physicalAddressController,
                label: 'Physical Address',
                validatorMessage: 'Please enter your address',
                icon: Icons.location_on,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _websiteController,
                label: 'Website/Social Media',
                validatorMessage: 'Please enter your website or social media link',
                icon: Icons.link,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context,
                controller: _descriptionController,
                label: 'Description',
                validatorMessage: 'Please describe what you do',
                icon: Icons.description,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Service Types',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              _buildServiceTypes(),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('24/7 Availability'),
                value: _isAvailable24x7,
                onChanged: (bool? newVal) {
                  setState(() {
                    _isAvailable24x7 = newVal ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Emergency Services'),
                value: _hasEmergencyServices,
                onChanged: (bool? newVal) {
                  setState(() {
                    _hasEmergencyServices = newVal ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          );
        }
      },
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && !_isSubmitting) {
      setState(() {
        _isSubmitting = true;
      });

      // Gather service types as array of strings where value is true.
      final selectedServices = _serviceTypes.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Create a map for the form data.
      final formData = {
        'email': _emailController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'domain': _domainController.text.trim(),
        'phone': _phoneController.text.trim(),
        'physicalAddress': _physicalAddressController.text.trim(),
        'website': _websiteController.text.trim(),
        'description': _descriptionController.text.trim(),
        'serviceTypes': selectedServices,
        'isAvailable24x7': _isAvailable24x7,
        'hasEmergencyServices': _hasEmergencyServices,
        'timestamp': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance
            .collection('partner_form_data')
            .add(formData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form submitted successfully!')),
        );
        // Pop the current context (returning to the main page)
        Navigator.pop(context);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adjust horizontal padding based on screen width.
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 32.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff6A11CB), Color(0xff2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Partner Form',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffE0EAFC), Color(0xffCFDEF3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 50,
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _buildResponsiveForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
      // Submit button fixed at the bottom wrapped in SafeArea.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(MaterialState.disabled)) return Colors.grey;
                    return Colors.transparent; // Use transparent to show the gradient.
                  },
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                elevation: MaterialStateProperty.all(0),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff6A11CB), Color(0xff2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

    );
  }
}