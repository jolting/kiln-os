# The IFS stall sensors as temperature sensors, so Fluidd graphs them.
# Happy Hare's analog encoder ([mmu_encoder] analog_pins) owns the four
# ADC pins, so the readings come from it: sensor_type ifs_stall, slot 1-4,
# value in raw 12-bit counts (0-4095), as Kiln's ifs_spoolN_stall.
#
# This file may be distributed under the terms of the GNU GPLv3 license.

SAMPLE_TIME = 0.25


class IfsStallSensor:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.reactor = self.printer.get_reactor()
        self.slot = config.getint('slot', minval=1, maxval=4)
        self.encoder_name = 'mmu_encoder ' + config.get('encoder', 'ifs_encoder')
        self.callback = None
        self.counter = None
        self.mcu = None
        self.temp = 0.
        self.timer = self.reactor.register_timer(self._sample)
        self.printer.register_event_handler('klippy:ready', self._ready)

    def setup_minmax(self, min_temp, max_temp):
        pass    # a raw reading is never a heater fault

    def setup_callback(self, cb):
        self.callback = cb

    def get_report_time_delta(self):
        return SAMPLE_TIME

    def _ready(self):
        encoder = self.printer.lookup_object(self.encoder_name, None)
        self.counter = getattr(encoder, 'counter', None)
        self.mcu = self.printer.lookup_object('mcu')
        self.reactor.update_timer(self.timer, self.reactor.NOW)

    def _sample(self, eventtime):
        values = getattr(self.counter, 'values_raw', None)
        if values and self.slot <= len(values):
            self.temp = float(values[self.slot - 1]) * 4095.
            if self.callback is not None:
                self.callback(self.mcu.estimated_print_time(eventtime),
                              self.temp)
        return eventtime + SAMPLE_TIME


class IfsStall:
    def __init__(self, config):
        pheaters = config.get_printer().load_object(config, 'heaters')
        pheaters.add_sensor_factory('ifs_stall', IfsStallSensor)


def load_config(config):
    return IfsStall(config)
