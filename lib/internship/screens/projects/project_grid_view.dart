import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myfellowpet_sp/internship/screens/projects/project_detail.dart';

/// Responsive helper function
double responsiveValue(BuildContext context, double mobile, double tablet, double laptop, double desktop) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 1440) return desktop;
  if (screenWidth > 1024) return laptop;
  if (screenWidth > 600) return tablet;
  return mobile;
}

class ProjectTile extends StatelessWidget {
  final String projectId;
  final String projectName;
  final List<dynamic> imageUrl;
  final String description;

  const ProjectTile({
    super.key,
    required this.projectId,
    required this.imageUrl,
    required this.description,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleProjectTap(context),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image with gradient overlay
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl[0],
                        fit: BoxFit.cover,
                        height: 180,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: responsiveValue(context, 16, 18, 20, 22),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: responsiveValue(context, 12, 14, 16, 18),
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Premium Badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: responsiveValue(context, 10, 12, 14, 16),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Start Button
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                onPressed: () => _handleProjectTap(context),
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProjectTap(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: responsiveValue(context, 16, 18, 20, 22),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please sign in to access this project.',
            style: TextStyle(
              fontSize: responsiveValue(context, 14, 16, 18, 20),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: responsiveValue(context, 14, 16, 18, 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectDetailPage(
            projectId: projectId,
            imageUrl: imageUrl,
            description: description,
            projectName: projectName,
          ),
        ),
      );
    }
  }
}

class ProjectGridView extends StatelessWidget {
  final String searchQuery;

  const ProjectGridView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('projects').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading projects: ${snapshot.error}',
              style: TextStyle(
                fontSize: responsiveValue(context, 14, 16, 18, 20),
              ),
            ),
          );
        }

        final projects = snapshot.data?.docs ?? [];
        final filteredProjects = projects.where((project) {
          final name = project['projectName']?.toString().toLowerCase() ?? '';
          return name.contains(searchQuery.toLowerCase());
        }).toList();

        if (filteredProjects.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded, size: responsiveValue(context, 48, 52, 56, 60), color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No projects found',
                  style: TextStyle(
                    fontSize: responsiveValue(context, 16, 18, 20, 22),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 340,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              final project = filteredProjects[index];
              return ProjectTile(
                projectId: project.id,
                imageUrl: project['imageUrls'],
                description: project['projectDescription'] ?? '',
                projectName: project['projectName'] ?? 'Untitled Project',
              );
            },
          ),
        );
      },
    );
  }
}
