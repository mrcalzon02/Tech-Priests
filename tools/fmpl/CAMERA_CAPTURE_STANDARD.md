# FMPL camera and capture authority — v0.4.0

**Hard production rule:** ONE fixed orthographic camera, 45 degrees elevation,
zero grid azimuth, zero lens shift, +Z up, fixed target determined from the
measured footprint and height. Rotate the machine, never the camera.

Approved capture types:
- entity: exactly four rotations [0,90,180,270], with static or animated
  frames within each orientation. Native Factorio N/E/S/W registration
  is prototype-specific. The boiler maps Blender source indices [0,3,2,1].
- item: exactly ONE icon state and ONE frame at rotation [0]. Never take
  additional close-up, rear, oblique or rotated item pictures.

No other viewpoints or persistent camera objects are allowed in a production
capture. An authorized sheet may arrange only already approved viewpoints.

The FMPL Blender camera guard clears old cameras in the **in-memory export
derivative**, creates the one named FMPL_CAPTURE_CAMERA, and checks the
actual camera transform and lens. The source scene on disk is untouched.
Cameras parenting geometry trigger an explicit failure rather than silently
breaking meshes. Temporary viewport inspection cameras use try/finally
cleanup and cannot survive into a saved model or capture receipt.

A former cluttered scene may be cleaned to a NEW .blend using:

    blender -b original.blend --python tools/fmpl/camera_cleanup_scene.py -- --profile tools/art/profiles/boiler-v08.json --out derived-clean.blend

Then verify that derived scene from a separate Blender load:

    blender -b derived-clean.blend --python tools/fmpl/camera_cleanup_scene.py -- --profile tools/art/profiles/boiler-v08.json --audit-only

Run offline camera-policy tests:

    python -m unittest discover -s tools/fmpl -p test_capture_policy.py

Source models must be visually reviewed, and game-native ports/graphic
offsets tested independently; a valid camera does not establish Factorio
playable integration or human acceptance.
