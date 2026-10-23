import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

// Original, deterministic PCM sounds. Run this script to regenerate assets/audio.
const sampleRate = 22050;
const output = resolve(import.meta.dirname, '..', 'assets', 'audio');
mkdirSync(output, { recursive: true });
let randomState = 0x5a17c0de;
const random = () => ((randomState = (1664525 * randomState + 1013904223) >>> 0) / 0x100000000) * 2 - 1;
const track = (seconds) => new Float32Array(Math.round(seconds * sampleRate));

function tone(audio, start, duration, frequency, gain, shape = 'pluck', drift = 0) {
  const first = Math.round(start * sampleRate);
  const count = Math.round(duration * sampleRate);
  let phase = 0;
  for (let i = 0; i < count && first + i < audio.length; i++) {
    const position = i / count;
    const attack = Math.min(1, i / (sampleRate * (shape === 'pad' ? 0.22 : 0.008)));
    const release = shape === 'pad'
      ? Math.min(1, (1 - position) / 0.16)
      : Math.exp(-4.4 * position) * Math.min(1, (1 - position) / 0.08);
    phase += 2 * Math.PI * (frequency + drift * position) / sampleRate;
    const fundamental = Math.sin(phase);
    const overtone = Math.sin(phase * 2.002) * (shape === 'pad' ? 0.13 : 0.20);
    audio[first + i] += (fundamental + overtone) * attack * release * gain;
  }
}

function rustle(audio, start, duration, gain, smooth = 0.88) {
  const first = Math.round(start * sampleRate);
  const count = Math.round(duration * sampleRate);
  let filtered = 0;
  for (let i = 0; i < count && first + i < audio.length; i++) {
    const position = i / count;
    filtered = filtered * smooth + random() * (1 - smooth);
    const fade = Math.sin(Math.PI * position) ** 1.4;
    audio[first + i] += filtered * fade * gain;
  }
}

function wav(audio, filename, peakTarget = 0.65) {
  let peak = 0;
  for (const value of audio) peak = Math.max(peak, Math.abs(value));
  // Normalize quiet synthesized sounds as well as limiting loud ones.
  const scale = peak > 0 ? peakTarget / peak : 1;
  const bytes = Buffer.alloc(44 + audio.length * 2);
  bytes.write('RIFF', 0);
  bytes.writeUInt32LE(bytes.length - 8, 4);
  bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(sampleRate, 24);
  bytes.writeUInt32LE(sampleRate * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36);
  bytes.writeUInt32LE(audio.length * 2, 40);
  for (let i = 0; i < audio.length; i++) {
    bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, audio[i] * scale)) * 32767), 44 + i * 2);
  }
  writeFileSync(join(output, filename), bytes);
  console.log(`${filename}: ${(audio.length / sampleRate).toFixed(2)}s, ${bytes.length} bytes`);
}

const garden = track(16);
const chords = [
  [130.81, 164.81, 196.00, 246.94], // Cmaj7
  [110.00, 130.81, 164.81, 196.00], // Am7
  [87.31, 130.81, 164.81, 196.00],  // Fmaj7
  [98.00, 146.83, 196.00, 220.00],  // G6
];
for (let bar = 0; bar < chords.length; bar++) {
  const start = bar * 4;
  for (const note of chords[bar]) tone(garden, start, 4.1, note, 0.025, 'pad');
  for (let beat = 0; beat < 8; beat++) {
    const note = chords[bar][[0, 2, 1, 3, 2, 1, 3, 1][beat]] * 2;
    tone(garden, start + beat * 0.5, 0.7, note, 0.030, 'pluck');
  }
}
for (const moment of [2.6, 7.4, 11.2, 14.5]) {
  tone(garden, moment, 0.20, 1080, 0.014, 'pluck', 560);
  tone(garden, moment + 0.15, 0.17, 1370, 0.010, 'pluck', -280);
}
rustle(garden, 0, 16, 0.025, 0.997);
for (let i = 0; i < garden.length; i++) {
  const edge = Math.min(1, i / (sampleRate * 0.25), (garden.length - 1 - i) / (sampleRate * 0.25));
  garden[i] *= Math.max(0, edge);
}
wav(garden, 'garden_loop.wav', 0.48);

const select = track(0.11);
tone(select, 0, 0.10, 660, 0.24);
tone(select, 0.012, 0.08, 990, 0.11);
wav(select, 'select.wav');

const plant = track(0.30);
tone(plant, 0, 0.24, 280, 0.32, 'pluck', -80);
rustle(plant, 0.03, 0.23, 0.42, 0.80);
wav(plant, 'plant.wav');

const water = track(0.60);
rustle(water, 0.02, 0.49, 0.52, 0.73);
for (const [at, frequency] of [[0.05, 370], [0.14, 520], [0.25, 430], [0.34, 610], [0.43, 380]]) {
  tone(water, at, 0.15, frequency, 0.10, 'pluck', -95);
}
wav(water, 'water.wav');

const fertilize = track(0.48);
rustle(fertilize, 0, 0.24, 0.20, 0.88);
for (const [at, frequency] of [[0.02, 740], [0.12, 988], [0.23, 1480]]) tone(fertilize, at, 0.22, frequency, 0.17);
wav(fertilize, 'fertilize.wav');

const harvest = track(0.85);
for (const [at, frequency] of [[0.02, 523], [0.15, 659], [0.29, 784], [0.43, 1047]]) tone(harvest, at, 0.40, frequency, 0.23);
wav(harvest, 'harvest.wav');

const day = track(0.72);
tone(day, 0.03, 0.48, 392, 0.20);
tone(day, 0.21, 0.48, 523, 0.22);
rustle(day, 0, 0.50, 0.10, 0.97);
wav(day, 'new_day.wav');

const upgrade = track(1.15);
for (const [at, frequency] of [[0.02, 392], [0.17, 523], [0.32, 659], [0.47, 784]]) tone(upgrade, at, 0.56, frequency, 0.22);
tone(upgrade, 0.48, 0.64, 1047, 0.16);
wav(upgrade, 'upgrade.wav');

const decorate = track(0.45);
tone(decorate, 0.01, 0.25, 330, 0.24, 'pluck', -35);
tone(decorate, 0.11, 0.29, 660, 0.17);
rustle(decorate, 0, 0.12, 0.23, 0.79);
wav(decorate, 'decorate.wav');
