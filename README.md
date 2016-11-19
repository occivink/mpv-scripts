# crop.lua

Crop the current video in a visual manner. UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping, there are other subtleties.

Press `c` to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.  
Press `alt-c` to undo the current crop.

Only works properly with `--video-unscaled`, dependency on [this issue](https://github.com/mpv-player/mpv/issues/3503).

# pan.lua

Pans the current video or image along with cursor movement as long as a button is pressed.

You can change the binding from `MOUSE_BTN0` to whatever you want, it doesn't even have to be a mouse button.

The default binding clashes with the window dragging feature, you can either set `--window-dragging=no` or change the binding.

The amount of panning is only correct if you start mpv with `--video-unscaled`, dependency on the same issue as with crop.lua.

Quick diagonal movement looks super shitty because setting the `video-pan-*` property triggers a vsync or something, to be determined.

# seek-to.lua

Seek to an absolute position in the current video.

Toggle with `ctrl+t`. Move the current cursor position with `left`, `right`. Change the number currently selected with the number keys (duh). Press `enter` to seek to the entered position.

I may add history in the future.

