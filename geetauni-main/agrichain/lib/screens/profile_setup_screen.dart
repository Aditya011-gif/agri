import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/firestore_models.dart';
import '../services/firebase_service.dart';
import '../services/profile_service.dart';
import '../main.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  final UserType userType;
  final String userName;
  final String userEmail;
  final String userPassword;

  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.userName,
    required this.userEmail,
    required this.userPassword,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Form Controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _gstController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  int _currentStep = 0;
  String? _selectedState;
  final List<String> _selectedCrops = [];
  final List<String> _selectedServices = [];

  // Profile Image
  String? _profileImagePath;

  // Indian States
  final List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  // Crop Options
  final List<String> _cropOptions = [
    'Wheat',
    'Rice',
    'Maize',
    'Barley',
    'Sugarcane',
    'Cotton',
    'Jute',
    'Potato',
    'Tomato',
    'Onion',
    'Garlic',
    'Cabbage',
    'Cauliflower',
    'Mango',
    'Apple',
    'Banana',
    'Orange',
    'Grapes',
    'Pomegranate',
    'Soybean',
    'Groundnut',
    'Mustard',
    'Sunflower',
    'Turmeric',
    'Chili',
  ];

  // Service Options for Buyers
  final List<String> _serviceOptions = [
    'Crop Procurement',
    'Storage Services',
    'Transportation',
    'Processing',
    'Export Services',
    'Quality Testing',
    'Financial Services',
    'Insurance',
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _farmSizeController.dispose();
    _businessNameController.dispose();
    _gstController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeProfileSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure user is authenticated in Firebase before creating profile
      final firebaseService = FirebaseService();
      final signInSuccess = await firebaseService.signInUser(
        email: widget.userEmail,
        password: widget.userPassword,
      );

      if (!signInSuccess) {
        if (mounted) {
          _showErrorSnackBar('Authentication failed. Please try again.');
        }
        return;
      }

      final profileService = ProfileService();
      final result = await profileService.completeProfile(
        userId: widget.userId,
        userType: widget.userType
            .toString()
            .split('.')
            .last, // Convert enum to string
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _selectedState!,
        pincode: _pincodeController.text.trim(),
        farmSize: widget.userType == UserType.farmer
            ? _farmSizeController.text.trim()
            : null,
        businessType: widget.userType == UserType.buyer
            ? _businessNameController.text.trim()
            : null,
        gstNumber: widget.userType == UserType.buyer
            ? _gstController.text.trim()
            : null,
        additionalData: {
          'bio': _bioController.text.trim(),
          'experience': _experienceController.text.trim(),
          'crops': _selectedCrops,
          'services': widget.userType == UserType.buyer
              ? _selectedServices
              : null,
          'profileImagePath': _profileImagePath,
        },
      );

      if (result['success'] == true) {
        // Refresh app state to load updated user data
        if (mounted) {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.refreshData();

          // Check mounted again after async operation
          if (mounted) {
            // Navigate to main app
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
              (route) => false,
            );

            _showSuccessSnackBar('Profile setup completed successfully!');
          }
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(result['message'] ?? 'Profile setup failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An error occurred during profile setup');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Progress Indicator
              _buildProgressIndicator(),

              // Form Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildLocationStep(),
                        _buildProfessionalStep(),
                        _buildPreferencesStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complete Your Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Help us personalize your AgriChain experience',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us where you are located',
            style: TextStyle(fontSize: 14, color: AppTheme.grey),
          ),
          const SizedBox(height: 24),

          // Address Field
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: _buildInputDecoration('Address', Icons.location_on),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // City and State Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: _buildInputDecoration(
                    'City',
                    Icons.location_city,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  decoration: _buildInputDecoration('State', Icons.map),
                  items: _indianStates.map((state) {
                    return DropdownMenuItem(value: state, child: Text(state));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedState = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'State is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pincode Field
          TextFormField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            decoration: _buildInputDecoration('Pincode', Icons.pin_drop),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Pincode is required';
              }
              if (value.length != 6) {
                return 'Please enter a valid 6-digit pincode';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Next Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_validateLocationStep()) {
                  _nextStep();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your professional background',
            style: TextStyle(fontSize: 14, color: AppTheme.grey),
          ),
          const SizedBox(height: 24),

          // Bio Field
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            decoration: _buildInputDecoration(
              'Bio/Description',
              Icons.description,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bio is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Experience Field
          TextFormField(
            controller: _experienceController,
            decoration: _buildInputDecoration(
              'Years of Experience',
              Icons.work,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Experience is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Conditional Fields based on User Type
          if (widget.userType == UserType.farmer) ...[
            TextFormField(
              controller: _farmSizeController,
              decoration: _buildInputDecoration(
                'Farm Size (in acres)',
                Icons.landscape,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Farm size is required';
                }
                return null;
              },
            ),
          ] else ...[
            TextFormField(
              controller: _businessNameController,
              decoration: _buildInputDecoration(
                widget.userType == UserType.fpo
                    ? 'FPO / Co-operative Name'
                    : (widget.userType == UserType.retailBuyer
                        ? 'Business / Display Name (Optional)'
                        : 'Company / Business Name'),
                Icons.business,
              ),
              validator: (value) {
                if (widget.userType == UserType.retailBuyer) return null;
                if (value == null || value.trim().isEmpty) {
                  return widget.userType == UserType.fpo
                      ? 'FPO name is required'
                      : 'Business name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _gstController,
              decoration: _buildInputDecoration(
                widget.userType == UserType.fpo
                    ? 'CIN / Registration / GSTIN (Optional)'
                    : 'GST Number (Optional)',
                Icons.receipt,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
          const SizedBox(height: 32),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_validateProfessionalStep()) {
                      _nextStep();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.userType == UserType.farmer
                ? 'Select crops you grow or plan to grow'
                : 'Select services you provide and crops you deal with',
            style: TextStyle(fontSize: 14, color: AppTheme.grey),
          ),
          const SizedBox(height: 24),

          // Crops Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Crops',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedCrops.length == _cropOptions.length) {
                      _selectedCrops.clear();
                    } else {
                      _selectedCrops.clear();
                      _selectedCrops.addAll(_cropOptions);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedCrops.length == _cropOptions.length && _cropOptions.isNotEmpty,
                        tristate: _selectedCrops.isNotEmpty && _selectedCrops.length < _cropOptions.length,
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selectedCrops.clear();
                              _selectedCrops.addAll(_cropOptions);
                            } else {
                              _selectedCrops.clear();
                            }
                          });
                        },
                        activeColor: AppTheme.primaryGreen,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        _selectedCrops.length == _cropOptions.length
                            ? 'Deselect All'
                            : 'Select All (${_cropOptions.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cropOptions.map((crop) {
              final isSelected = _selectedCrops.contains(crop);
              return FilterChip(
                label: Text(crop),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCrops.add(crop);
                    } else {
                      _selectedCrops.remove(crop);
                    }
                  });
                },
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primaryGreen,
              );
            }).toList(),
          ),

          // Services Selection (for buyers only)
          if (widget.userType == UserType.buyer) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedServices.length == _serviceOptions.length) {
                        _selectedServices.clear();
                      } else {
                        _selectedServices.clear();
                        _selectedServices.addAll(_serviceOptions);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _selectedServices.length == _serviceOptions.length && _serviceOptions.isNotEmpty,
                          tristate: _selectedServices.isNotEmpty && _selectedServices.length < _serviceOptions.length,
                          onChanged: (bool? val) {
                            setState(() {
                              if (val == true) {
                                _selectedServices.clear();
                                _selectedServices.addAll(_serviceOptions);
                              } else {
                                _selectedServices.clear();
                              }
                            });
                          },
                          activeColor: AppTheme.primaryGreen,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          _selectedServices.length == _serviceOptions.length
                              ? 'Deselect All'
                              : 'Select All (${_serviceOptions.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceOptions.map((service) {
                final isSelected = _selectedServices.contains(service);
                return FilterChip(
                  label: Text(service),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedServices.add(service);
                      } else {
                        _selectedServices.remove(service);
                      }
                    });
                  },
                  selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 32),

          // Complete Setup Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _completeProfileSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Complete Setup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Back Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  bool _validateLocationStep() {
    return _addressController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _selectedState != null &&
        _pincodeController.text.length == 6;
  }

  bool _validateProfessionalStep() {
    bool baseValidation =
        _bioController.text.trim().isNotEmpty &&
        _experienceController.text.trim().isNotEmpty;

    if (widget.userType == UserType.farmer) {
      return baseValidation && _farmSizeController.text.trim().isNotEmpty;
    } else if (widget.userType == UserType.retailBuyer) {
      return baseValidation;
    } else {
      return baseValidation && _businessNameController.text.trim().isNotEmpty;
    }
  }
}
