Widget _buildAddShopCard(BuildContext context) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
    ),
    child: InkWell(
      onTap: () {
        // 🚀 Replacing context.go('/business-type')
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RunTypeSelectionPage(
              // Assuming this page requires user/auth details
              uid: FirebaseAuth.instance.currentUser!.uid,
              phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',
              email: FirebaseAuth.instance.currentUser!.email ?? '',
              serviceId: null, // Indicates a new service/branch is being created
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      hoverColor: accentColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_business_outlined, color: accentColor, size: 24),
            const SizedBox(width: 12),
            Text(
              'Register a New Business',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}