<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { config } from '../../config';

const props = defineProps({ open: { type: Boolean, default: false }, room: { type: Number, default: 99 } });
const emit = defineEmits(['close', 'capture']);
const { t } = useI18n();

const videoEl = ref(null);
const mode = ref('photo'); // photo | video
const facing = ref('environment');
const recording = ref(false);
const seconds = ref(0);
const error = ref('');
const added = ref(0);
const flash = ref(false);
const ready = ref(false);

let stream = null;
let recorder = null;
let chunks = [];
let timer = null;
let recMime = '';

const canCapture = computed(() => ready.value && !error.value && props.room > 0);
const mirror = computed(() => facing.value === 'user');
const clock = computed(() => `${String(Math.floor(seconds.value / 60)).padStart(2, '0')}:${String(seconds.value % 60).padStart(2, '0')}`);

function stopStream() {
  stream?.getTracks().forEach((tr) => tr.stop());
  stream = null;
  ready.value = false;
}

async function start() {
  stopStream();
  error.value = '';
  if (!navigator.mediaDevices?.getUserMedia) { error.value = 'unsupported'; return; }
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: facing.value }, width: { ideal: 1920 }, height: { ideal: 1080 } },
      audio: mode.value === 'video', // the microphone is only requested when filming
    });
  } catch (e) {
    error.value = e?.name === 'NotAllowedError' || e?.name === 'SecurityError' ? 'denied' : 'unsupported';
    return;
  }
  await nextTick();
  if (!videoEl.value) { stopStream(); return; }
  videoEl.value.srcObject = stream;
  try { await videoEl.value.play(); } catch { /* autoplay is allowed for muted streams */ }
  ready.value = true;
}

function close() {
  if (recording.value) discardRecording();
  stopStream();
  emit('close');
}

watch(() => props.open, (o) => { if (o) { added.value = 0; mode.value = 'photo'; start(); } else { stopStream(); } }, { immediate: true });
onBeforeUnmount(() => { clearInterval(timer); stopStream(); });
if (typeof document !== 'undefined') document.addEventListener('visibilitychange', () => { if (document.hidden && props.open) close(); });

async function setMode(m) {
  if (recording.value || m === mode.value) return;
  mode.value = m;
  await start();
}
async function flip() {
  if (recording.value) return;
  facing.value = facing.value === 'environment' ? 'user' : 'environment';
  await start();
}

async function shoot() {
  const v = videoEl.value;
  if (!v?.videoWidth) return;
  const canvas = document.createElement('canvas');
  canvas.width = v.videoWidth; canvas.height = v.videoHeight;
  canvas.getContext('2d').drawImage(v, 0, 0);
  const blob = await new Promise((r) => canvas.toBlob(r, 'image/jpeg', 0.92));
  canvas.width = canvas.height = 0;
  if (!blob) return;
  emit('capture', [new File([blob], `camera-${Date.now()}.jpg`, { type: 'image/jpeg' })]);
  added.value++;
  flash.value = true;
  setTimeout(() => { flash.value = false; }, 160);
}

function pickMime() {
  const list = ['video/mp4;codecs=avc1', 'video/webm;codecs=vp9,opus', 'video/webm;codecs=vp8,opus', 'video/webm', 'video/mp4'];
  return typeof MediaRecorder !== 'undefined' ? list.find((m) => MediaRecorder.isTypeSupported(m)) || '' : '';
}

function startRecording() {
  if (!stream || typeof MediaRecorder === 'undefined') { error.value = 'unsupported'; return; }
  recMime = pickMime();
  chunks = [];
  try { recorder = new MediaRecorder(stream, { ...(recMime ? { mimeType: recMime } : {}), videoBitsPerSecond: 2_500_000 }); } catch { error.value = 'unsupported'; return; }
  recorder.ondataavailable = (e) => { if (e.data?.size) chunks.push(e.data); };
  recorder.onstop = () => {
    clearInterval(timer);
    recording.value = false;
    if (!chunks.length) return;
    const type = (recorder.mimeType || recMime || 'video/webm').split(';')[0];
    const ext = type.includes('mp4') ? 'mp4' : 'webm';
    emit('capture', [new File(chunks, `camera-${Date.now()}.${ext}`, { type })]);
    added.value++;
    chunks = [];
  };
  recorder.start(1000);
  recording.value = true;
  seconds.value = 0;
  timer = setInterval(() => { seconds.value++; if (seconds.value >= config.maxVideoSeconds) stopRecording(); }, 1000);
}
function stopRecording() { if (recorder && recorder.state !== 'inactive') recorder.stop(); }
function discardRecording() { chunks = []; if (recorder) { recorder.onstop = null; if (recorder.state !== 'inactive') recorder.stop(); } clearInterval(timer); recording.value = false; }

const onShutter = () => (mode.value === 'photo' ? shoot() : recording.value ? stopRecording() : startRecording());

// fallback when the live camera is unavailable: the device's own camera app through a file input
function fromDevice(e) {
  const files = Array.from(e.target.files || []);
  e.target.value = '';
  if (files.length) { emit('capture', files); added.value += files.length; }
}
function onKey(e) {
  if (!props.open) return;
  if (e.key === 'Escape') close();
  if (e.key === ' ' && canCapture.value) { e.preventDefault(); onShutter(); }
}
if (typeof document !== 'undefined') document.addEventListener('keydown', onKey);
onBeforeUnmount(() => document.removeEventListener('keydown', onKey));
</script>

<template>
  <Teleport to="body"><div v-if="open" class="camera" role="dialog" aria-modal="true" :aria-label="t('camera.title')">
    <video ref="videoEl" class="cam-feed" :class="{ mirror }" playsinline muted autoplay />
    <div v-if="flash" class="cam-flash" />

    <header class="cam-bar cam-top">
      <button class="icon-btn" :aria-label="t('close')" @click="close"><AppIcon name="x" :size="22" /></button>
      <span v-if="recording" class="cam-rec"><i />{{ clock }}</span>
      <span class="grow" />
      <button class="icon-btn" :aria-label="t('camera.switch')" :disabled="recording || !!error" @click="flip"><AppIcon name="refresh" :size="22" /></button>
    </header>

    <div v-if="error" class="cam-fallback">
      <AppIcon name="alert" :size="28" />
      <p>{{ t(error === 'denied' ? 'camera.denied' : 'camera.noCamera') }}</p>
      <label class="btn primary">{{ t('camera.useApp') }} · {{ t('camera.photo') }}<input class="sr" type="file" accept="image/*" capture="environment" @change="fromDevice" /></label>
      <label class="btn">{{ t('camera.useApp') }} · {{ t('camera.video') }}<input class="sr" type="file" accept="video/*" capture="environment" @change="fromDevice" /></label>
    </div>

    <footer class="cam-bar cam-bottom">
      <div class="cam-modes" role="tablist">
        <button role="tab" :aria-selected="mode === 'photo'" :class="{ on: mode === 'photo' }" :disabled="recording" @click="setMode('photo')">{{ t('camera.photo') }}</button>
        <button role="tab" :aria-selected="mode === 'video'" :class="{ on: mode === 'video' }" :disabled="recording" @click="setMode('video')">{{ t('camera.video') }}</button>
      </div>
      <div class="cam-row">
        <span class="cam-count">{{ added ? t('camera.added', { n: added }) : '' }}</span>
        <button class="shutter" :class="[mode, { recording }]" :disabled="!canCapture && !recording" :aria-label="mode === 'photo' ? t('camera.shutter') : recording ? t('camera.stop') : t('camera.record')" @click="onShutter"><i /></button>
        <button class="btn primary sm cam-done" @click="close">{{ t('camera.done') }}</button>
      </div>
      <p v-if="room <= 0" class="cam-limit">{{ t('camera.full') }}</p>
    </footer>
  </div></Teleport>
</template>

<style scoped>
/* Own stacking context straight under <body> (Teleport) and sized to the VISIBLE viewport (svh), so the controls
   are never pushed under a phone's browser bar. Layout is a flex column: top bar / camera / controls. */
.camera { position: fixed; top: 0; left: 0; right: 0; height: 100vh; height: 100svh; z-index: 90; background: #000; color: #fff; display: flex; flex-direction: column; overflow: hidden; }
.cam-feed { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; background: #000; }
.cam-feed.mirror { transform: scaleX(-1); }
.cam-flash { position: absolute; inset: 0; background: #fff; opacity: .85; animation: fade .16s reverse; pointer-events: none; z-index: 3; }
.cam-bar { position: relative; z-index: 2; display: flex; align-items: center; gap: 10px; padding: 14px 16px; flex: none; }
.cam-bar.cam-top { padding-top: calc(14px + env(safe-area-inset-top)); background: linear-gradient(rgba(0,0,0,.55), transparent); }
.cam-bar.cam-bottom { margin-top: auto; flex-direction: column; gap: 14px; padding-bottom: calc(22px + env(safe-area-inset-bottom)); background: linear-gradient(transparent, rgba(0,0,0,.65)); }
.cam-bar .icon-btn { color: #fff; background: rgba(255,255,255,.16); }
.cam-rec { display: inline-flex; align-items: center; gap: 8px; padding: 4px 12px; border-radius: 999px; background: rgba(0,0,0,.5); font-variant-numeric: tabular-nums; font-weight: 600; }
.cam-rec i { width: 10px; height: 10px; border-radius: 50%; background: #ff4d4d; animation: blink 1s infinite; }
@keyframes blink { 50% { opacity: .25; } }
.cam-modes { display: inline-flex; gap: 4px; padding: 4px; border-radius: 999px; background: rgba(0,0,0,.45); }
.cam-modes button { border: 0; background: transparent; color: rgba(255,255,255,.75); padding: 6px 16px; border-radius: 999px; font-weight: 550; font-size: 14px; }
.cam-modes button.on { background: #fff; color: #000; }
.cam-row { width: 100%; max-width: 420px; display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; }
.cam-count { font-size: 13px; opacity: .9; }
.cam-done { justify-self: end; }
.shutter { width: 74px; height: 74px; flex: none; border-radius: 50%; border: 4px solid #fff; background: transparent; padding: 0; display: grid; place-items: center; }
.shutter i { width: 56px; height: 56px; border-radius: 50%; background: #fff; transition: all .15s; }
.shutter.video i { background: #ff4d4d; }
.shutter.recording i { width: 28px; height: 28px; border-radius: 8px; }
.shutter:active i { transform: scale(.9); }
.shutter:disabled { opacity: .55; }
.cam-limit { font-size: 13px; color: #ffd27a; }
.cam-fallback { position: absolute; inset: 0; z-index: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 14px; padding: 90px 24px 190px; text-align: center; background: rgba(8,10,9,.92); }
.cam-fallback p { max-width: 36ch; line-height: 1.5; }
.cam-fallback .btn { cursor: pointer; }
@media (max-height: 560px) { .shutter { width: 60px; height: 60px; } .shutter i { width: 44px; height: 44px; } .cam-bar.cam-bottom { gap: 8px; } }
</style>
