import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'register_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                // Logo and Tagline
                Row(
                  children: [
                    const Text(
                      'Crop Select',
                      style: TextStyle(
                        fontFamily: 'GreatVibes',
                        fontSize: 42,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/leaf_icon.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.eco,
                            color: AppColors.primaryGreen);
                      },
                    ),
                  ],
                ),
                const Text(
                  'start your greenary journey',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 60),
                // Email and Password Section
                const Text(
                  'Enter your email and password',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                const CustomTextField(
                  hintText: 'email@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                const CustomTextField(
                  hintText: 'password',
                  isPassword: true,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Login',
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'New to Crop Select ?  ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Plant Image
                Center(
                  child: Image.asset(
                    'assets/images/plant_hand.png',
                    height: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 280,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          size: 100,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
