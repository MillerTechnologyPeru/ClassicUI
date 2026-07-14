package org.pureswift.classicui;

import android.os.Build;
import android.view.View;
import android.view.WindowManager;
import org.libsdl.app.SDLActivity;

/**
 * SDLActivity (from the vendored SDL3 Java glue, Vendor/java/SDL3-android.jar) drives the whole
 * native lifecycle: it loads the libraries below in order, creates the SDL surface, and invokes
 * libClassicUIAndroid.so's exported {@code SDL_main} on a dedicated thread (see
 * ports/Android/Sources/ClassicUIAndroid/AndroidMain.swift).
 */
public class MainActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL3",
            // Last entry doubles as the "main" shared object SDLActivity dlsym's SDL_main from.
            "ClassicUIAndroid",
        };
    }

    /**
     * Hides the status/nav bars ("immersive sticky": swiping from an edge reveals them
     * temporarily, then they auto-hide again) so the iPod screen truly fills the display -
     * the Theme.ClassicUI manifest theme removes the action bar and lets content draw under
     * the cutout/status bar area, but doesn't hide the system bars themselves.
     *
     * Re-applied on every focus change, not just onCreate: the system bars reappear whenever
     * focus is lost (e.g. a dialog, the recents switcher) and won't rehide on their own when
     * focus returns.
     */
    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemBars();
        }
    }

    private void hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
            android.view.WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(android.view.WindowInsets.Type.statusBars()
                    | android.view.WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }
}
