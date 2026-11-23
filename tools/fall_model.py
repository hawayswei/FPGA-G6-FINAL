"""Bit-exact Python copy of rtl/fall/fall_detect.v and rtl/fall/fall_param_lut.v.

Used by:
  * gen_fall_vectors.py  - makes the test vectors for sim/fall/tb_fall_detect.v
  * analyze_trials.py    - replays recorded trials to see what the FPGA would decide

If you change the Verilog, change this file the same way (and the other way
round), then re-run gen_fall_vectors.py and the testbench.

Units: 1 g is about 250 LSB (ADXL362 at +-8 g). Sample rate 100 Hz.
"""

G_LSB = 250          # LSB per g
SAMPLE_HZ = 100

IDLE, ARMED, SETTLE, STILL, EVAL = range(5)
STATE_NAMES = ["IDLE", "ARMED", "SETTLE", "STILL", "EVAL"]

MODE_ADULT, MODE_ELDERLY, MODE_SPORT = 0, 1, 2
MODE_NAMES = {MODE_ADULT: "adult", MODE_ELDERLY: "elderly", MODE_SPORT: "sport"}


def g_to_sq(g):
    """Threshold in g -> squared LSB value used by the hardware."""
    return int(round(g * G_LSB)) ** 2


def param_lut(mode, height_cm):
    """Same table as rtl/fall/fall_param_lut.v. Returns (lft_sq, uft_sq, window)."""
    if mode == MODE_ELDERLY:
        lft_sq, uft_sq = 150 * 150, 500 * 500      # 0.6 g, 2.0 g
    elif mode == MODE_SPORT:
        lft_sq, uft_sq = 100 * 100, 750 * 750      # 0.4 g, 3.0 g
    else:
        lft_sq, uft_sq = 125 * 125, 625 * 625      # 0.5 g, 2.5 g
    if height_cm < 150:
        window = 60
    elif height_cm < 165:
        window = 65
    elif height_cm < 180:
        window = 70
    else:
        window = 75
    return lft_sq, uft_sq, window


def mag_sq(x, y, z):
    """Squared magnitude, saturated to 24 bits like the hardware."""
    return min(x * x + y * y + z * z, 0xFFFFFF)


class FallDetector:
    """One call to step() per sample. Returns True on the sample where the
    hardware would pulse fall_o."""

    def __init__(self, lft_sq=125 * 125, uft_sq=625 * 625, window=70, posture_en=False,
                 ff_min_samples=5, settle_samples=100, still_samples=200,
                 still_max_bad=30, still_lo_sq=40000, still_hi_sq=90000,
                 posture_dot_max=44000, ref_period=100, avg_shift=5):
        self.lft_sq, self.uft_sq, self.window = lft_sq, uft_sq, window
        self.posture_en = posture_en
        self.ff_min_samples = ff_min_samples
        self.settle_samples = settle_samples
        self.still_samples = still_samples
        self.still_max_bad = still_max_bad
        self.still_lo_sq, self.still_hi_sq = still_lo_sq, still_hi_sq
        self.posture_dot_max = posture_dot_max
        self.ref_period = ref_period
        self.avg_shift = avg_shift
        self.reset()

    def reset(self):
        self.state = IDLE
        self.ff_cnt = self.win_cnt = self.cnt = self.bad_cnt = self.ref_cnt = 0
        self.acc = [0, 0, 0]
        self.ref_new = [0, 0, 0]
        self.ref_old = [0, 0, 0]
        self.ref = [0, 0, 0]
        self.last_mag_sq = 0
        self.last_bad_cnt = 0
        self.last_dot = 0

    def _avg(self):
        # Python >> on negative integers is an arithmetic shift, like Verilog >>>
        return [a >> self.avg_shift for a in self.acc]

    def step(self, x, y, z):
        m = mag_sq(x, y, z)
        self.last_mag_sq = m
        low, high = m < self.lft_sq, m > self.uft_sq
        moving = m < self.still_lo_sq or m > self.still_hi_sq
        avg = self._avg()                      # value before this sample's update
        fall = False

        if self.state == IDLE:
            ref_old_before = list(self.ref_old)
            if self.ref_cnt == self.ref_period - 1:
                self.ref_cnt = 0
                self.ref_old = list(self.ref_new)
                self.ref_new = list(avg)
            else:
                self.ref_cnt += 1
            if low:
                if self.ff_cnt + 1 >= self.ff_min_samples:
                    self.state = ARMED
                    self.win_cnt = self.window
                    self.ff_cnt = 0
                    self.ref = ref_old_before
                else:
                    self.ff_cnt += 1
            else:
                self.ff_cnt = 0
        elif self.state == ARMED:
            if high:
                self.state, self.cnt = SETTLE, self.settle_samples
            elif low:
                self.win_cnt = self.window
            elif self.win_cnt == 0:
                self.state = IDLE
            else:
                self.win_cnt -= 1
        elif self.state == SETTLE:
            if self.cnt <= 1:
                self.state, self.cnt, self.bad_cnt = STILL, self.still_samples, 0
            else:
                self.cnt -= 1
        elif self.state == STILL:
            if moving and self.bad_cnt != 0xFFFF:
                self.bad_cnt += 1
            if self.cnt <= 1:
                self.state = EVAL
            else:
                self.cnt -= 1
        elif self.state == EVAL:
            dot = sum(r * a for r, a in zip(self.ref, avg))
            self.last_dot, self.last_bad_cnt = dot, self.bad_cnt
            if self.bad_cnt <= self.still_max_bad and (not self.posture_en or dot < self.posture_dot_max):
                fall = True
            self.state = IDLE
            self.ref_cnt = 0

        # gravity low-pass update (same clock edge as the FSM step in hardware)
        for i, v in enumerate((x, y, z)):
            self.acc[i] = self.acc[i] + v - avg[i]
        return fall


def run(samples, **kwargs):
    """Run a whole recording. samples = iterable of (x, y, z).
    Returns the list of sample indices where a fall was reported."""
    det = FallDetector(**kwargs)
    return [i for i, (x, y, z) in enumerate(samples) if det.step(x, y, z)]
