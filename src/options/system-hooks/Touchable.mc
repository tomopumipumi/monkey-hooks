import Toybox.Lang;
import Toybox.Math;

module MonkeyHooks {
    module Touchable {
        private var _areas as Array<Dictionary>? = null;

        enum {
            _TYPE_RECT = 0,
            _TYPE_CIRCLE = 1
        }

        function registerRect(
            id as Object,
            x as Number,
            y as Number,
            width as Number,
            height as Number
        ) as Void {
            if (_areas == null) {
                _areas = [] as Array<Dictionary>;
            }
            _areas.add({
                :type => _TYPE_RECT,
                :id => id,
                :x => x,
                :y => y,
                :w => width,
                :h => height
            });
        }

        function registerCircle(
            id as Object,
            cx as Number,
            cy as Number,
            radius as Float or Number
        ) as Void {
            if (_areas == null) {
                _areas = [] as Array<Dictionary>;
            }
            _areas.add({
                :type => _TYPE_CIRCLE,
                :id => id,
                :cx => cx,
                :cy => cy,
                :r => radius
            });
        }

        function clear() as Void {
            _areas = null;
        }

        function handleTap(x as Number, y as Number) as Object? {
            if (_areas == null) {
                return null;
            }

            for (var i = _areas.size() - 1; i >= 0; i--) {
                var area = _areas[i] as Dictionary;
                var type = area[:type] as Number;

                switch (type) {
                    case _TYPE_RECT:
                        var ax = area[:x] as Number;
                        var ay = area[:y] as Number;
                        var aw = area[:w] as Number;
                        var ah = area[:h] as Number;

                        if (
                            x >= ax &&
                            x <= ax + aw &&
                            y >= ay &&
                            y <= ay + ah
                        ) {
                            return area[:id];
                        }
                        break;
                        
                    case _TYPE_CIRCLE:
                        var cx = area[:cx] as Number;
                        var cy = area[:cy] as Number;
                        var r = area[:r] as Float or Number;

                        // (x - cx)^2 + (y - cy)^2 <= r^2
                        var dx = x - cx;
                        var dy = y - cy;
                        if (dx * dx + dy * dy <= r * r) {
                            return area[:id];
                        }
                        break;
                }
            }
            return null;
        }
    }
}
