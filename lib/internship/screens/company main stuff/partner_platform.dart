import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myfellowpet_sp/internship/screens/company%20main%20stuff/partner_form.dart';

class PartnersPlatform extends StatelessWidget {
  const PartnersPlatform({Key? key}) : super(key: key);

  // Helper to build feature points with dynamic styling.
  Widget _buildFeaturePoint(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 600 ? 12 : 16;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: fontSize + 8),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build each step in the process with modern styling.
  Widget _buildStep({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xff2575FC),
        child: Text(
          stepNumber,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
    );
  }

  // LEFT SECTION: Image with gradient overlay and feature points.
  Widget _buildLeftSection(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = screenWidth < 600 ? 16.0 : 48.0;
    double verticalPadding = screenWidth < 600 ? 16.0 : 32.0;

    double headlineFontSize;
    if (screenWidth < 400) {
      headlineFontSize = 18;
    } else if (screenWidth < 600) {
      headlineFontSize = 24;
    } else {
      headlineFontSize = 32;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'partnerpage.jpg',
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.2)
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: screenWidth * 0.8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Join 8M+ Businesses\nTrusting Our Platform',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: headlineFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildFeaturePoint(context, Icons.rocket_launch,
                  'Scale your business with our powerful tools'),
              _buildFeaturePoint(context, Icons.auto_graph,
                  'Advanced analytics & performance insights'),
              _buildFeaturePoint(context, Icons.support_agent,
                  '24/7 dedicated partner support'),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // RIGHT SECTION: Steps and Proceed button.
  Widget _buildRightSection(BuildContext context, {required bool isLargeScreen}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isLargeScreen
            ? const BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        )
            : null,
        boxShadow: isLargeScreen
            ? const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(-4, 0),
          ),
        ]
            : null,
      ),
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How We Connect with You',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We value your time and want to make the partnership process as seamless as possible. Follow the steps below, and we’ll be in touch soon!',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              // Step 1
              _buildStep(
                stepNumber: '1',
                title: 'Proceed to Our Partner Form',
                subtitle:
                'Click the "Proceed" button below to access our partnership form.',
              ),
              const SizedBox(height: 8),
              // Step 2
              _buildStep(
                stepNumber: '2',
                title: 'Fill Out Your Details',
                subtitle:
                'Provide your contact information, business name, and a brief description of what you do.',
              ),
              const SizedBox(height: 8),
              // Step 3
              _buildStep(
                stepNumber: '3',
                title: 'We’ll Reach Out Shortly',
                subtitle:
                'Once we receive your information, our team will contact you to discuss next steps and assist you further.',
              ),
              const SizedBox(height: 32),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.8, // Button takes 80% of the screen width
                  child: ElevatedButton(
                    onPressed: () {
                      // Authentication check for the Proceed button.
                      if (FirebaseAuth.instance.currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in to access this feature.')),
                        );
                        Navigator.pushNamed(context, '/signin');
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PartnerFormPage(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2575FC),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Proceed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to switch between a Row (large screen) and a Column (small screen) layout.
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Modern AppBar with gradient background and custom back arrow.
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
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Partners Platform',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isLargeScreen = constraints.maxWidth >= 800;
            if (isLargeScreen) {
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildLeftSection(context),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildRightSection(context, isLargeScreen: true),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.72,
                      width: double.infinity,
                      child: _buildLeftSection(context),
                    ),
                    _buildRightSection(context, isLargeScreen: false),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}