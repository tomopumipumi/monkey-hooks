import Toybox.Lang;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Test;

module MonkeyHooks {
    module TestUtils {
        function resetStore() as Void {
            MonkeyHooks._globalStore = null;
        }

        function injectState(states as Dictionary) as Void {
            var store = MonkeyHooks.getStore();
            var keys = states.keys();
            for (var i = 0; i < keys.size(); i++) {
                var k = keys[i];
                store.setSilent(k, states.get(k));
            }
        }

        function createDummyDc(
            width as Number,
            height as Number
        ) as Graphics.Dc {
            var bitmapRef = Graphics.createBufferedBitmap({
                :width => width,
                :height => height
            });
            return bitmapRef.get().getDc();
        }

        function benchmarkRender(
            logger as Test.Logger,
            dc as Graphics.Dc,
            renderMethod as Lang.Method,
            props as Array,
            iterations as Number,
            testName as String
        ) as Number {
            var start = System.getTimer();
            for (var i = 0; i < iterations; i++) {
                renderMethod.invoke(dc, props);
            }
            var elapsed = System.getTimer() - start;

            var msPerFrame = elapsed.toFloat() / iterations;
            logger.debug(
                Lang.format("Benchmark [$1$]: Total $2$ms ($3$ms / frame)", [
                    testName,
                    elapsed,
                    msPerFrame.format("%.2f")
                ])
            );

            return elapsed;
        }
    }
}
