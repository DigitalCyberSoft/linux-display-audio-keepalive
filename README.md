# Linux Display Audio Keepalive

A systemd user service that prevents HDMI/DisplayPort audio from cutting out by maintaining a silent audio stream.

## The Problem

Many displays, monitors, and AV receivers aggressively power down their audio processing when no sound is playing. This causes several annoying issues:

- **First sound cutoff**: The first 0.5-2 seconds of audio gets lost when playback starts after silence
- **Audio pops/clicks**: Audible artifacts when the audio hardware wakes up
- **Delayed audio start**: Noticeable lag before sound begins playing
- **Periodic dropouts**: Some devices (especially those with One Connect boxes) drop audio for 1-2 seconds periodically

This happens because HDMI and DisplayPort embed audio in the video signal. When audio stops, the receiver's DAC and audio processing circuitry enter sleep mode. Re-initialization takes time, causing the symptoms above.

## Samsung Odyssey Ark 2nd Gen / One Connect Box

The Samsung Odyssey Ark 2nd Gen with its One Connect Box is particularly affected by this issue:

- **Periodic audio drops**: Users report sound cutting out for 1-2 seconds approximately every 45-60 minutes
- **External source issues**: The problem primarily affects devices connected via the One Connect Box's HDMI ports, while internal apps work fine
- **Dolby Digital processing**: There appears to be an issue with how the One Connect Box processes Dolby Digital signals from external sources
- **Audio delay**: Some users experience ~200ms audio delay when using eARC with external receivers
- **Signal renegotiation**: The One Connect Box may trigger HDMI/DP link renegotiation during periods of silence, causing brief audio interruptions

The One Connect Box acts as an intermediary between your PC and the display, and its power management behavior can be more aggressive than direct connections. This service works around these issues by ensuring continuous audio data flow.

### Related Samsung Issues

These problems have been reported across multiple Samsung devices with One Connect boxes, including:
- Samsung Odyssey Ark (1st and 2nd Gen)
- Samsung The Frame series
- Samsung QLED TVs (Q95TD and similar)
- Samsung S95C/S95D OLED TVs with eARC

## How It Works

The service uses `pacat` (PulseAudio/PipeWire audio tool) to continuously stream silence to the audio output:

```bash
pacat -p --rate=48000 --channels=2 --format=s16le /dev/zero
```

| Parameter | Purpose |
|-----------|---------|
| `-p` | Playback mode |
| `--rate=48000` | 48kHz sample rate (standard for HDMI audio) |
| `--channels=2` | Stereo output |
| `--format=s16le` | 16-bit signed little-endian PCM |
| `/dev/zero` | Source of silence (continuous zeros) |

This keeps the audio link active without producing audible sound, preventing the receiver from entering sleep mode.

## Requirements

- Linux with systemd
- PulseAudio or PipeWire (with pipewire-pulse)
- `pulseaudio-utils` package (provides `pacat`)

### Installing Dependencies

**Fedora:**
```bash
sudo dnf install pulseaudio-utils
```

**Ubuntu/Debian:**
```bash
sudo apt install pulseaudio-utils
```

**Arch Linux:**
```bash
sudo pacman -S libpulse
```

## Installation

```bash
./install.sh
```

Or manually:

```bash
cp hdmi-keepalive.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now hdmi-keepalive.service
```

## Uninstallation

```bash
./install.sh --uninstall
```

Or manually:

```bash
systemctl --user disable --now hdmi-keepalive.service
rm ~/.config/systemd/user/hdmi-keepalive.service
systemctl --user daemon-reload
```

## Verifying It Works

Check service status:
```bash
systemctl --user status hdmi-keepalive.service
```

Verify the silent stream is active:
```bash
pactl list clients | grep pacat
```

## Troubleshooting

### Service fails to start

Ensure `pacat` is installed:
```bash
which pacat
```

### Audio still cuts out

The service streams to the default audio sink. If you have multiple audio outputs, you may need to modify the service to target a specific sink:

```bash
pacat -p --rate=48000 --channels=2 --format=s16le --device=YOUR_SINK_NAME /dev/zero
```

Find your sink name with:
```bash
pactl list sinks short
```

### High CPU usage

This service should use negligible CPU (<0.1%). If you see high usage, check for other audio issues or try restarting PulseAudio/PipeWire.

## License

MIT License - Use freely, modify as needed.
