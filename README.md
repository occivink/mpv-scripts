# crop.lua

Crop the current video in a visual manner. UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping and handles additionnal properties (pan, zoom), there are other subtleties.

Press `c` to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.  
You can use a binding such as `f vf del -1` to undo the last crop.

# drag-to-pan.lua

Pans the current video or image along with cursor movement as long as a button is pressed.

You can change the binding from `MOUSE_BTN0` to whatever you want, it doesn't even have to be a mouse button.
The default binding clashes with the window dragging feature, you can either set `window-dragging=no` in your config or change the binding.

Quick diagonal movement looks shitty because setting the `video-pan-*` property triggers a full pipeline or something, to be determined.

# seek-to.lua

Seek to an absolute position in the current video.

Toggle with `ctrl+t`. Move the current cursor position with `left`, `right`. Change the number currently selected with the number keys (duh). Press `enter` to seek to the entered position.

I may add history in the future.

# filters.lua

Some not-very-useful helper commands for handling filters and what not.
