// You must import the dart:html library
import 'dart:html' as html;

void updateSeoMeta({
  required String shopName,
  required String areaName,
  required String serviceType,
  required String description,
}) {
  // --- 1. Update the Page Title (CRITICAL for ranking) ---
  final titleElement = html.document.querySelector('title');
  if (titleElement != null) {
    // The title should be rich in keywords but readable.
    titleElement.text =
    '$shopName – Best $serviceType in $areaName | MyFellowPet';
  }

  // --- 2. Update the Meta Description ---
  // The description doesn't directly boost ranking, but it improves the click-through rate (CTR),
  // which Google uses as a strong signal.
  html.Element? metaDesc = html.document.querySelector('meta[name="description"]');
  if (metaDesc == null) {
    metaDesc = html.MetaElement()..name = 'description';
    html.document.head!.append(metaDesc);
  }

  // Ensure the description is compelling and includes location/service keywords.
  final finalDescription = description.isNotEmpty
      ? description
      : 'Find trusted, MFP-Certified $serviceType in $areaName. Book safe and reliable pet care with $shopName today.';

  (metaDesc as html.MetaElement).content = finalDescription;
}