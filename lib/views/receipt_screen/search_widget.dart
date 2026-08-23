import 'package:collector_app/common/app/theme.dart';
import 'package:collector_app/common/utils/size_utils.dart';
import 'package:collector_app/common/widget/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final bool showSearchBy;
  final int selectedIndex;
  final VoidCallback onFilterPressed;
  final ValueChanged<int> onTogglePressed;
  final VoidCallback onQRPressed;
  final bool isQrShow;

  const SearchBarWidget(
      {super.key,
      required this.searchController,
      required this.showSearchBy,
      required this.selectedIndex,
      required this.onFilterPressed,
      required this.onTogglePressed,
      required this.onQRPressed,
      required this.isQrShow});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        if (showSearchBy) _buildSearchBy(),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return SizedBox(
      height: 39,
      child: Row(
        children: [
          Expanded(
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.1),
                      blurRadius: 3,
                      spreadRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: TextField(
                  autofocus: false,
                  controller: searchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onFilterPressed,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SvgPicture.asset(
                              'assets/icons/filter.svg',
                              height: 20,
                              width: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    hintText: "Search by account name or number",
                    contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(9.0),
                      child: SvgPicture.asset(
                        'assets/icons/search_icon.svg',
                        height: 20,
                        width: 20,
                      ),
                    ),
                  ),
                )),
          ),
          SizedBox(width: 10.hp),
          if (isQrShow) _buildQRScannerButton(context),
        ],
      ),
    );
  }

  Widget _buildQRScannerButton(BuildContext context) {
    return GestureDetector(
      onTap: onQRPressed,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.1),
                blurRadius: 3,
                spreadRadius: 3,
                offset: const Offset(0, 1),
              ),
            ]),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/qrImage.svg',
              colorFilter: const ColorFilter.mode(
                CustomTheme.appThemeColorPrimary,
                BlendMode.srcIn,
              ),
              width: 25.hp,
              height: 25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBy() {
    return Container(
      padding: const EdgeInsets.only(top: 5),
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(8),
        borderColor: CustomTheme.appThemeColorPrimary,
        selectedBorderColor: CustomTheme.appThemeColorPrimary,
        fillColor: CustomTheme.appThemeColorPrimary.withOpacity(0.2),
        isSelected: [selectedIndex == 0, selectedIndex == 1],
        onPressed: onTogglePressed,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Text(
              "General",
              style: TextStyle(
                color: selectedIndex == 0
                    ? CustomTheme.appThemeColorPrimary
                    : Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Text(
              "Group Name",
              style: TextStyle(
                color: selectedIndex == 1
                    ? CustomTheme.appThemeColorPrimary
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
