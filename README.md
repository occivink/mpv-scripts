# pan.lua

Pans the current video or image along with cursor movement.

You can change the binding from MOUSE_BTN0 to whatever you want, it doesn't even have to be a mouse button.

The amount of panning is only correct if you start mpv with `--video-unscaled`, dependency on [this issue](https://github.com/mpv-player/mpv/issues/3503#issuecomment-258299545). Also zoom is not handled yet.

Quick diagonal movement looks super shitty because setting the `video-pan-*` property triggers a vsync or something, to be determined.

# seek-to.lua

Seek to an absolute position in the current video.

Toggle with `ctrl+t`. Move the current cursor position with `left`, `right`. Change the number currently selected with the number keys (duh). Press `enter` to seek to the entered position.

I may add history in the future.

