ios-clean:
	- cd ios && rm -rf Pods
	- cd ios && rm -rf Podfile.lock
	- cd ios && pod install --repo-update
	- cd ios && open Runner.xcworkspace  