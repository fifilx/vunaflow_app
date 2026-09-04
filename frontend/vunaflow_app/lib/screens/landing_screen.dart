import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/vunaflow_logo.dart';
import 'auth/client_login_screen.dart';
import 'auth/staff_login_screen.dart';
import 'auth/register_screen.dart';

typedef Lang = String;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Lang _lang = 'en';
  final _scrollController = ScrollController();
  final _whatWeDoKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _galleryKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 860;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1E15),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _NavBar(
              isMobile: isMobile,
              lang: _lang,
              onLanguageToggle: () => setState(() => _lang = _lang == 'en' ? 'sw' : 'en'),
              onFeatures: () => _scrollTo(_featuresKey),
              onGallery: () => _scrollTo(_galleryKey),
              onContact: () => _scrollTo(_contactKey),
            ),
            _BotanicalHeroSection(
              isMobile: isMobile,
              lang: _lang,
              onLearnMore: () => _scrollTo(_whatWeDoKey),
            ),
            Container(key: _whatWeDoKey, child: _BotanicalCardsGrid(isMobile: isMobile, lang: _lang)),
            _LivestockAndCropsShowcase(isMobile: isMobile, lang: _lang),
            Container(key: _galleryKey, child: _PhotoGallerySection(isMobile: isMobile, lang: _lang)),
            _GrowthCycleTrack(isMobile: isMobile, lang: _lang),
            Container(key: _featuresKey, child: _BotanicalFeaturesSection(isMobile: isMobile, lang: _lang)),
            _FaqSection(isMobile: isMobile, lang: _lang),
            Container(key: _contactKey, child: _Footer(isMobile: isMobile, lang: _lang)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Navigation Bar (Bilingual English / Swahili)
// ---------------------------------------------------------------------------
class _NavBar extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  final VoidCallback onLanguageToggle;
  final VoidCallback onFeatures;
  final VoidCallback onGallery;
  final VoidCallback onContact;

  const _NavBar({
    required this.isMobile,
    required this.lang,
    required this.onLanguageToggle,
    required this.onFeatures,
    required this.onGallery,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF122318),
          border: Border(bottom: BorderSide(color: Color(0x28FFFFFF))),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : (isMobile ? 18 : 48),
          vertical: isCompact ? 8 : 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo — shrink slightly on small screens
            Flexible(
              child: VunaFlowLogo(
                size: isCompact ? 24 : (isMobile ? 28 : 36),
                showWordmark: screenWidth > 320,
                textColor: Colors.white,
              ),
            ),
            if (!isMobile)
              Row(
                children: [
                  _NavLink(isSw ? 'Nyumbani' : 'Home', () {}),
                  const SizedBox(width: 24),
                  _NavLink(isSw ? 'Vipengele' : 'Features', onFeatures),
                  const SizedBox(width: 24),
                  _NavLink(isSw ? 'Mazao & Mifugo' : 'Farms & Livestock', onGallery),
                  const SizedBox(width: 24),
                  _NavLink(isSw ? 'Mawasiliano' : 'Contact', onContact),
                ],
              ),
            // Right actions — on mobile use a compact pill menu that cannot overflow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Language toggle chip
                InkWell(
                  onTap: onLanguageToggle,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 12,
                      vertical: isCompact ? 5 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language, size: 14, color: AppColors.goldPale),
                        const SizedBox(width: 4),
                        Text(
                          isSw ? 'SW' : 'EN',
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldPale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 6 : 10),

                if (isCompact) ...[
                  // Compact dropdown login selector on small phones
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'client') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                        );
                      } else if (val == 'staff') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
                        );
                      }
                    },
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSw ? 'Ingia' : 'Login',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF122318),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF122318)),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'client',
                        child: Row(
                          children: [
                            const Icon(Icons.person_outlined, size: 18, color: Color(0xFF133826)),
                            const SizedBox(width: 8),
                            Text(isSw ? 'Mkulima (Client)' : 'Client Portal'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'staff',
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF133826)),
                            const SizedBox(width: 8),
                            Text(isSw ? 'Afisa (Staff)' : 'Staff Portal'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Tablet / Desktop separate buttons
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white60),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isSw ? 'Mkulima' : 'Client',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF122318),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      elevation: 0,
                    ),
                    child: Text(
                      isSw ? 'Afisa' : 'Staff',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.publicSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.parchment,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Botanical Hero Section (Bilingual)
// ---------------------------------------------------------------------------
class _BotanicalHeroSection extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  final VoidCallback onLearnMore;

  const _BotanicalHeroSection({
    required this.isMobile,
    required this.lang,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3B29), Color(0xFF122318), Color(0xFF0F1E15)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroContent(context, isSw),
                    const SizedBox(height: 36),
                    _buildHeroLeafCard(isSw),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 12, child: _buildHeroContent(context, isSw)),
                    const SizedBox(width: 48),
                    Expanded(flex: 10, child: _buildHeroLeafCard(isSw)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroContent(BuildContext context, bool isSw) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x28F1DDAF),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0x50F1DDAF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, color: AppColors.goldPale, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isSw ? 'RUZUKU NA MKOPO WA MAZAO NA MIFUGO' : 'CROPS & LIVESTOCK FINANCING',
                  style: GoogleFonts.publicSans(
                    fontSize: isMobile ? 10.5 : 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldPale,
                    letterSpacing: isMobile ? 0.5 : 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RichText(
          text: TextSpan(
            style: GoogleFonts.fraunces(
              color: AppColors.parchment,
              fontSize: isMobile ? 38 : 58,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
            children: [
              TextSpan(text: isSw ? 'Kuwezesha\nWakulima & ' : 'Empowering\nFarmers & '),
              TextSpan(
                text: isSw ? 'Wafugaji' : 'Livestock',
                style: GoogleFonts.fraunces(
                  fontStyle: FontStyle.italic,
                  color: AppColors.goldPale,
                ),
              ),
              TextSpan(text: isSw ? '\nNchini Kote.' : '\nKeepers Nationwide.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isSw
              ? 'Iwe unalima mazao (Mahindi, Kahawa, Chai, Mboga) au unafuga mifugo (Ng\'ombe wa maziwa, Kuku, Mbuzi, Samaki), VunaFlow inatoa mikopo, usimamizi wa hati, na ushauri wa papo hapo.'
              : 'Whether you grow crops (Maize, Coffee, Tea, Horticulture) or keep livestock (Dairy, Cattle, Poultry, Goats, Aquaculture), VunaFlow provides flexible credit, document management, and real-time advisory.',
          style: GoogleFonts.publicSans(
            fontSize: 16.5,
            height: 1.6,
            color: const Color(0xD9F5F2E7),
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.shamba900,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                isSw ? 'Omba Mkopo →' : 'Apply for Loan →',
                style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton(
              onPressed: onLearnMore,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.parchment,
                side: const BorderSide(color: Color(0x60F5F2E7), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(isSw ? 'Tazama Huduma' : 'Explore Services'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroLeafCard(bool isSw) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/Tropical coconut plantation_.jfif',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xE6122318)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSw ? 'Mikopo Endelevu kwa Kilimo na Ufugaji' : 'Sustainable Financing for Kenya\'s Harvest',
                    style: GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 3D Embossed Botanical Grid (Bilingual)
// ---------------------------------------------------------------------------
class _BotanicalCardsGrid extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _BotanicalCardsGrid({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    final tiles = [
      _BotanicalTile(
        isSw ? 'Mikopo ya Mazao' : 'Crop Financing',
        isSw ? 'Mtaji wa Mahindi, Kahawa, Chai na Mboga' : 'Flexible capital for Maize, Coffee, Tea & Vegetables',
        Icons.grass,
        const Color(0xFF2B5A3F),
      ),
      _BotanicalTile(
        isSw ? 'Mikopo ya Mifugo' : 'Livestock Loans',
        isSw ? 'Fedha za Ng\'ombe wa Maziwa, Kuku, na Mbuzi' : 'Funding for Dairy Cows, Poultry, Beef & Sheep',
        Icons.pets,
        const Color(0xFF6D4C3D),
      ),
      _BotanicalTile(
        isSw ? 'Ushauri wa Kilimo' : 'Farm Advisory',
        isSw ? 'Ushauri wa Udongo, Chakula cha Mifugo na Hali ya Hewa' : 'Expert guidance on soil, feed, milk yield & weather',
        Icons.wb_sunny_outlined,
        const Color(0xFF7A5230),
      ),
      _BotanicalTile(
        isSw ? 'Zana & Mashine' : 'Equipment & Tools',
        isSw ? 'Pampu za Maji, Matrekta na Majengo ya Mifugo' : 'Irrigation pumps, tractors & slatted housing',
        Icons.precision_manufacturing_outlined,
        const Color(0xFF1E3B29),
      ),
    ];

    return Container(
      color: const Color(0xFF0F1E15),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 48 : 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'HUDUMA ZETU' : 'WHAT WE OFFER',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSw ? 'Mikopo Maalum kwa Kilimo na Ufugaji.' : 'Tailored financing for crops and livestock keepers.',
                style: GoogleFonts.fraunces(
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parchment,
                ),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 700 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 140,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (context, idx) {
                      final item = tiles[idx];
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x30F5F2E7), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0x28F5F2E7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, color: AppColors.goldPale, size: 28),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.title,
                                    style: GoogleFonts.fraunces(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.parchment,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      color: const Color(0xD9F5F2E7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotanicalTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  _BotanicalTile(this.title, this.subtitle, this.icon, this.bgColor);
}

// ---------------------------------------------------------------------------
// 4. Livestock & Crops Showcase (Bilingual)
// ---------------------------------------------------------------------------
class _LivestockAndCropsShowcase extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _LivestockAndCropsShowcase({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    return Container(
      color: const Color(0xFF14271B),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'SEKTA ZA KILIMO NA UFUGAJI' : 'AGRICULTURAL & LIVESTOCK SECTORS',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSw ? 'Kugharamia Kila Miradi ya Kilimo Nchini Kenya.' : 'Funding every farming endeavor across Kenya.',
                style: GoogleFonts.fraunces(
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parchment,
                ),
              ),
              const SizedBox(height: 36),
              isMobile
                  ? Column(
                      children: [
                        _buildShowcaseCard(isSw ? 'Mifugo & Maziwa' : 'Livestock & Dairy', 'cows.jfif', isSw ? 'Mikopo ya ng\'ombe wa maziwa, kuku, na mbuzi.' : 'Dairy cows, beef cattle, poultry, and sheep/goat loans.'),
                        const SizedBox(height: 20),
                        _buildShowcaseCard(isSw ? 'Kilimo cha Kahawa' : 'Coffee Plantations', 'coffee.jfif', isSw ? 'Fedha za usafishaji, kupogoa, na kuongeza kahawa.' : 'Financing berry expansion, pruning, and washing stations.'),
                        const SizedBox(height: 20),
                        _buildShowcaseCard(isSw ? 'Wakulima wa Chai' : 'Tea Smallholders', 'tea.jfif', isSw ? 'Msaada wa kuchuma chai na mbolea ya NPK.' : 'Support for regular plucking cycles and NPK fertilizers.'),
                        const SizedBox(height: 20),
                        _buildShowcaseCard(isSw ? 'Mboga & Maua' : 'Horticulture & Flowers', 'rows of flowers.jfif', isSw ? 'Uwagiliaji wa matone, nyumba za kioo na maua.' : 'Drip irrigation, greenhouses, and export crop capital.'),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildShowcaseCard(isSw ? 'Mifugo & Maziwa' : 'Livestock & Dairy', 'cows.jfif', isSw ? 'Ng\'ombe wa maziwa & kuku.' : 'Dairy cows & poultry loans.')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildShowcaseCard(isSw ? 'Kahawa' : 'Coffee Farming', 'coffee.jfif', isSw ? 'Kupogoa & mtaji wa kahawa.' : 'Coffee pruning & berry capital.')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildShowcaseCard(isSw ? 'Chai' : 'Tea Estates', 'tea.jfif', isSw ? 'Kuchuma chai & mbolea.' : 'Plucking & fertilizer financing.')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildShowcaseCard(isSw ? 'Mboga & Maua' : 'Horticulture', 'rows of flowers.jfif', isSw ? 'Uwagiliaji wa matone.' : 'Greenhouses & drip irrigation.')),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseCard(String title, String imageFile, String desc) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/$imageFile', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFA122318)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.parchment,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.publicSans(
                      fontSize: 12.5,
                      color: const Color(0xD9F5F2E7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Photo Gallery Showcase (Bilingual)
// ---------------------------------------------------------------------------
class _PhotoGallerySection extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _PhotoGallerySection({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    return Container(
      color: const Color(0xFF0F1E15),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 48 : 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'PICHA ZA MASHAMBA NA MIFUGO' : 'FARM & LIVESTOCK GALLERY',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSw ? 'Wakulima wa Kweli Wanaotumia VunaFlow.' : 'Real Kenyan farmers using VunaFlow.',
                style: GoogleFonts.fraunces(
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parchment,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    flex: 12,
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/Tropical coconut plantation_.jfif'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/cows.jfif'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Growth Cycle Track (Bilingual)
// ---------------------------------------------------------------------------
class _GrowthCycleTrack extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _GrowthCycleTrack({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    final steps = isSw
        ? [
            '1. Sajili Wasifu',
            '2. Chagua Zao/Mifugo',
            '3. Omba Mtandaoni',
            '4. Pakia Hati',
            '5. Ukaguzi wa Afisa',
            '6. Fuatilia Mkopo',
            '7. Kupokea Fedha',
          ]
        : [
            '1. Register Profile',
            '2. Select Crop/Livestock',
            '3. Apply Online',
            '4. Upload Documents',
            '5. Officer Review',
            '6. Live Tracking',
            '7. Disbursement',
          ];

    return Container(
      color: const Color(0xFF1B3524),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 48 : 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'HATUA 7 ZA MKOPO' : 'SEVEN-STAGE LOAN CYCLE',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: steps.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x35F5F2E7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0x40F5F2E7)),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.publicSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.parchment,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Features Section (Bilingual)
// ---------------------------------------------------------------------------
class _BotanicalFeaturesSection extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _BotanicalFeaturesSection({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    return Container(
      color: const Color(0xFF0F1E15),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 48 : 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'UWEZO WA MFUMO' : 'PLATFORM CAPABILITIES',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSw ? 'Imejengwa kwa Wakulima na Maafisa wa Mikopo.' : 'Built for both farmers and loan officers.',
                style: GoogleFonts.fraunces(
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parchment,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureBox(
                      isSw ? 'Kwa Wakulima & Wafugaji' : 'For Farmers & Livestock Keepers',
                      isSw
                          ? [
                              'Omba mikopo kwa dakika chache kutoka kwa simu yako',
                              'Pakia hati za shamba na kitambulisho kwa usalama',
                              'Pata ushauri maalum wa mazao na mifugo',
                              'Fuatilia hali ya mkopo wako papo hapo',
                            ]
                          : [
                              'Apply for loans in minutes from your phone',
                              'Upload title deeds & national ID securely',
                              'Receive tailored crop & livestock advice',
                              'Track application status in real time',
                            ],
                    ),
                  ),
                  if (!isMobile) const SizedBox(width: 24),
                  if (!isMobile)
                    Expanded(
                      child: _buildFeatureBox(
                        isSw ? 'Kwa Maafisa wa Matawi' : 'For Branch Officers & Staff',
                        isSw
                            ? [
                                'Mfumo wa kukagua maombi kwa pamoja',
                                'Uhakiki wa hati na ufunguzi wa faili',
                                'Kumbukumbu za ukaguzi na ufuatiliaji',
                                'Arifa za moja kwa moja kwa wakulima',
                              ]
                            : [
                                'Centralized application review queue',
                                'Direct file verification & previewing',
                                'Audit trail & progress status tracking',
                                'Automated client notifications',
                              ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBox(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3323),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x35F5F2E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.parchment),
          ),
          const SizedBox(height: 16),
          Column(
            children: items.map((i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.goldPale, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i,
                        style: GoogleFonts.publicSans(fontSize: 14, color: const Color(0xD9F5F2E7)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. FAQ Section (Bilingual)
// ---------------------------------------------------------------------------
class _FaqSection extends StatefulWidget {
  final bool isMobile;
  final Lang lang;
  const _FaqSection({required this.isMobile, required this.lang});

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final isSw = widget.lang == 'sw';

    final faqs = isSw
        ? [
            _FaqItem('Je, ninaweza kuomba mkopo wa mifugo?', 'Ndiyo! VunaFlow inaunga mkono mikopo ya ng\'ombe wa maziwa, kuku, mbuzi, na samaki.'),
            _FaqItem('Ni hati gani ninazopaswa kupakia?', 'Kitambulisho cha Taifa halali, Hati ya shamba au mkataba wa kukodi, na ushahidi wa dhamana.'),
            _FaqItem('Ninawezaje kupata ushauri wa kilimo?', 'Fungua tabu ya Ushauri wa Kilimo na Mifugo kwenye dashibodi yako kupata ushauri maalum.'),
            _FaqItem('Kukubaliwa kwa mkopo huchukua muda gani?', 'Maombi mengi hukaguliwa na afisa wa tawi ndani ya siku 3 hadi 5 za kazi.'),
          ]
        : [
            _FaqItem('Can I apply for a livestock loan?', 'Yes! VunaFlow supports loans for dairy cattle, beef, poultry, goats, sheep, and fish farming.'),
            _FaqItem('What documents do I need to upload?', 'Valid National ID, Title Deed or proof of land ownership, and any collateral proof.'),
            _FaqItem('How do I receive farming and livestock advice?', 'Access the Farming & Livestock Advice tab in your dashboard for tailored recommendations.'),
            _FaqItem('How fast is loan approval?', 'Most complete applications are reviewed within 3 to 5 business days by your local branch officer.'),
          ];

    return Container(
      color: const Color(0xFF14271B),
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 20 : 48, vertical: widget.isMobile ? 48 : 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw ? 'MASWALI YANAYOULIZWA MARA KWA MARA' : 'FREQUENTLY ASKED QUESTIONS',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: List.generate(faqs.length, (idx) {
                  final isOpen = _openIndex == idx;
                  final item = faqs[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3B29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x28F5F2E7)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _openIndex = isOpen ? null : idx),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.question,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.parchment,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: AppColors.goldPale,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isOpen)
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                            child: Text(
                              item.answer,
                              style: GoogleFonts.publicSans(
                                fontSize: 14.5,
                                color: const Color(0xD9F5F2E7),
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem(this.question, this.answer);
}

// ---------------------------------------------------------------------------
// 9. Contact & Footer Section (HIGH-CONTRAST VISIBILITY)
// ---------------------------------------------------------------------------
class _Footer extends StatelessWidget {
  final bool isMobile;
  final Lang lang;
  const _Footer({required this.isMobile, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isSw = lang == 'sw';

    return Container(
      color: const Color(0xFF122318), // Deep emerald background
      child: Column(
        children: [
          // Contact Details Container with High Contrast & Gold Headings
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 48,
              vertical: isMobile ? 48 : 64,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isMobile
                    ? Column(
                        children: [
                          _buildContactCard(Icons.email_outlined, isSw ? 'BARUA PEPE' : 'EMAIL', 'info@vunaflow.co.ke'),
                          const SizedBox(height: 20),
                          _buildContactCard(Icons.phone_outlined, isSw ? 'SIMU' : 'PHONE', '020-2718840 / +254 700 000 000'),
                          const SizedBox(height: 20),
                          _buildContactCard(Icons.access_time, isSw ? 'MASAA YA KAZI' : 'OFFICE HOURS', isSw ? 'Jumatatu–Ijumaa, 8:00–17:00' : 'Mon–Fri, 8:00–17:00'),
                          const SizedBox(height: 20),
                          _buildContactCard(Icons.location_on_outlined, isSw ? 'TAWI LA KARIBU' : 'BRANCH LOCATOR', isSw ? 'Matawi 43 Nchini Kenya' : '43 Branches Nationwide'),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildContactCard(Icons.email_outlined, isSw ? 'BARUA PEPE' : 'EMAIL', 'info@vunaflow.co.ke')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildContactCard(Icons.phone_outlined, isSw ? 'SIMU' : 'PHONE', '020-2718840 / +254 700 000 000')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildContactCard(Icons.access_time, isSw ? 'MASAA YA KAZI' : 'OFFICE HOURS', isSw ? 'Jumatatu–Ijumaa, 8:00–17:00' : 'Mon–Fri, 8:00–17:00')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildContactCard(Icons.location_on_outlined, isSw ? 'TAWI LA KARIBU' : 'BRANCH LOCATOR', isSw ? 'Matawi 43 Nchini Kenya' : '43 Branches Nationwide')),
                        ],
                      ),
              ),
            ),
          ),
          // Footer Bottom Strip
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x35F5F2E7))),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 48,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const VunaFlowLogo(size: 26, showWordmark: true, textColor: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            '© 2026 VunaFlow',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 12,
                              color: AppColors.goldPale,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Digital Agricultural & Livestock Financing',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              color: AppColors.goldPale.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const VunaFlowLogo(size: 28, showWordmark: true, textColor: Colors.white),
                          Text(
                            '© 2026 VunaFlow — Digital Agricultural & Livestock Financing Platform',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 12.5,
                              color: AppColors.goldPale,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3B29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.goldPale),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldPale,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.publicSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.parchment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
