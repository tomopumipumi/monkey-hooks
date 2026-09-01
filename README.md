# MonkeyHooks

MonkeyHooks is a state management and utility library for Garmin Connect IQ (Monkey C) application development.

It is designed to improve maintainability by organizing processes such as UI state management, system resource sharing (timers and GPS), and screen transitions.

## Use Case: YAMAKAGE

The Garmin application "YAMAKAGE" is a practical example of MonkeyHooks in action.

[YAMAKAGE(Repository)](https://github.com/tomopumipumi/yamakage)<br>
[YAMAKAGE(Connect IQ)](https://apps.garmin.com/apps/48e48601-9506-4f67-b19c-59ca702c34b8?tid=2)


![HQaPT2Ka4AAXXRo.jpg](https://github.com/user-attachments/assets/8cda2c1b-71e9-45c9-a873-01fe399476ad)

![HQaPT2ebIAEco02.jpg](https://github.com/user-attachments/assets/c363b3c0-c0e2-4ab2-af67-b42399e87cba)

![HQaPT2Wa0AAZi5R.jpg](https://github.com/user-attachments/assets/3b663b69-eb33-4a11-a9c9-3e8a8cf78543)

![HQaPT2KaEAEJMK0.jpg](https://github.com/user-attachments/assets/36c16aa4-fcb5-4ce4-abcc-b3acbbe83209)


Under the strict CPU and memory constraints of Garmin devices, implementing complex UIs—such as sun and moon orbit calculations, panoramic views, and animations—usually presents a major challenge in balancing "performance preservation" and "code maintainability."

By utilizing the state management and caching mechanisms of MonkeyHooks, YAMAKAGE organizes complex state transitions and data flows to enhance maintainability, while achieving practical performance, such as smooth rendering and low power consumption.

---

## Core Design

MonkeyHooks is designed based on the following paradigms:

1. **Centralized State Management:**
It has a single `Store` shared across the entire app. States are managed by keys and can be accessed and updated from any component.
2. **Automatic Render Updates:**
When a state is updated via `set()`, it detects the change, automatically calls `WatchUi.requestUpdate()`, and re-evaluates dependent listeners and computed properties.
3. **Type Safety and Null Checking:**
To address Monkey C's characteristics, it provides type-specific contexts such as `useNumber` and `useString`. By using the `req()` method, you can safely access values under the assumption that they exist (throws an exception if null).
4. **Opt-in Design and Resource Sharing:**
It adopts a modular structure (opt-in design) allowing you to include only necessary features in your project. Additionally, `SharedTimer` and `LocationHook` share a single system resource even when referenced by multiple components, preventing memory leaks through internal weak references (WeakReference).

---

## Architecture

```mermaid
graph TD
    classDef store fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef hooks fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef sys fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef view fill:#ffffff,stroke:#666666,stroke-width:2px,color:#000
    classDef comp fill:#ffffff,stroke:#666666,stroke-width:1px,color:#000
    classDef os fill:#f9f9f9,stroke:#cccccc,stroke-width:2px,color:#000

    subgraph "Garmin OS / Hardware"
        Sensors((GPS / Timer)):::os
        Storage[(Local Storage)]:::os
        Screen((Watch Screen)):::os
    end

    subgraph "MonkeyHooks Framework"
        SystemH["System Hooks<br/>(LocationHook, SharedTimer)"]:::sys
        Router[Data-Driven Router]:::sys
        Store[(Global Store)]:::store
        
        Hooks["Type-Safe Hooks<br/>(useNumber, useString...)"]:::hooks
        Computed[useComputed]:::hooks
    end

    subgraph "Application"
        Delegate[Behavior Delegate]:::view
        View[View]:::view
        Dumb[Components]:::comp
    end

    Sensors -->|Single resource sharing| SystemH
    Storage <-->|Auto save/restore| Hooks
    
    SystemH -->|Callback| View
    Delegate -->|"set() state update"| Hooks
    Hooks -->|Write| Store
    
    Store -->|Read / Notify| Hooks
    Store -->|Read| Computed

    Hooks --->|"get() / req()"| View
    Computed --->|"req()"| View
    
    View -->|Pass as arguments| Dumb
    Dumb -->|Render| Screen
    
    Store -.->|Detect Route_ID| Router
    Router -.->|push / switchTo| Screen


```

---

## Installation

We recommend installing MonkeyHooks as a Git submodule.

### 1. Add Submodule

Run the following command in the root directory of your project to add the library:

```bash
git submodule add https://github.com/tomopumipumi/monkey-hooks.git lib/monkey-hooks

```

### 2. Configure `monkey.jungle`

Edit `monkey.jungle` at the root of your application and add the `src` folder of MonkeyHooks to the source path for compilation.

```jungle
project.manifest = manifest.xml

# Specify the submodule's src folder in addition to the existing source
base.sourcePath = source;lib/monkey-hooks/src

```

---

## Recommended Architecture: Props Packing Pattern & Pure Render Functions

To achieve both "smooth rendering performance" and "high testability" on Garmin devices, MonkeyHooks recommends a UI design using the "Props Packing Pattern."

This involves packing all the states a View holds into a single "Array" and passing it to a stateless "pure function" for rendering, aiming to separate responsibilities and enhance testability.

Regarding performance, testing with the WatchApp version of `YAMAKAGE` confirmed an execution time drop of about 1ms. However, considering the testability benefits, this is within a negligible range and the advantages outweigh the costs in moderately sized apps.

### Implementation Example

#### **1. Props Index Definition**

To avoid magic numbers, define the array indices using an `enum` and leave type comments.

```monkeyc
module MainProps {
    enum {
        W = 0,        // Number
        H,            // Number
        IS_ANIM_ON,   // Boolean
        PROGRESS,     // Float
        DATA_SIZE = 4 // Number of array elements
    }
}

```

#### **2. Pure Render Module**

Create a module solely responsible for rendering. Unpack the received array into local variables at the beginning.

```monkeyc
module MainRender {
    function render(dc as Graphics.Dc, props as Array) as Void {
        // Unpack into local variables at the beginning
        var w = props[MainProps.W] as Number;
        var h = props[MainProps.H] as Number;
        var isAnimOn = props[MainProps.IS_ANIM_ON] as Boolean;
        var progress = props[MainProps.PROGRESS] as Float;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // From here, use local variables for rendering processes
        // ...
    }
}

```

#### **3. View Container**

The `View` class focuses solely on "monitoring/updating states" and "data packing." All instance variables related to rendering are eliminated and consolidated into the `_props` array.

```monkeyc
class MainView extends WatchUi.View {
    // Consolidate all cache data into a single array
    private var _props as Array = new [MainProps.DATA_SIZE];

    function onLayout(dc as Graphics.Dc) as Void {
        _props[MainProps.W] = MonkeyHooks.useNumber(:width).req();
        _props[MainProps.H] = MonkeyHooks.useNumber(:height).req();
    }

    function onTimerTick() as Void {
        if (_props[MainProps.IS_ANIM_ON] as Boolean) {
            _props[MainProps.PROGRESS] = (_props[MainProps.PROGRESS] as Float) + 0.1;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // The View merely delegates the state to the render function (no side effects)
        MainRender.render(dc, _props);
    }
}

```

### Benefits of this Pattern

* **Separation of State and Rendering:** It shares the same philosophy as React, improving the visibility of View code that is often cluttered with dozens of variables.
* **Enabling Headless UI Testing:** By simply passing a dummy array and Dc to `MainRender.render()`, you can run UI crash tests and benchmarks without running the entire system.

---

## Usage

### 1. Basic State Management

Initialize and update states using type-specific hooks (`useNumber`, `useString`, `useBoolean`, etc.).

```monkeyc
class MyDelegate extends WatchUi.BehaviorDelegate {
    private var _counter = MonkeyHooks.useNumber(:counter);

    function onSelect() {
        // Update the state (WatchUi.requestUpdate() is automatically triggered)
        _counter.set(_counter.req() + 1);
        return true;
    }
}

```

### 2. Subscribing to and Rendering State in UI (Push-based Caching)

Due to the CPU constraints of Garmin devices, calling `MonkeyHooks.use...` inside `onUpdate` (which is executed every frame) introduces dictionary lookup overhead.
We recommend a "push-based architecture" where you cache states into class variables within `onShow` and monitor changes using `watch`.

```monkeyc
import Toybox.WatchUi;
import Toybox.Graphics;

class MyView extends WatchUi.View {
    // Cache variable for rendering
    private var _currentCount as Number = 0;

    function initialize() {
        View.initialize();
        MonkeyHooks.useNumber(:counter).init(0); // Initialize Store
    }

    function onShow() {
        // 1. Fetch and cache the latest value from the Store upon initial display
        _currentCount = MonkeyHooks.useNumber(:counter).req();

        // 2. Register a listener that fires only when the state changes (Push notification)
        MonkeyHooks.watch(self, :onCounterChanged, [:counter]);
    }

    function onHide() {
        // Unregister monitoring to prevent memory leaks
        MonkeyHooks.unwatch(self, :onCounterChanged);
    }

    // Called only when the value changes, keeping the cache up-to-date
    function onCounterChanged(vals as Array) as Void {
        if (vals[0] != null) {
            _currentCount = vals[0] as Number;
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Do not call MonkeyHooks inside onUpdate; use only cache variables
        dc.drawText(100, 100, Graphics.FONT_LARGE, "Count: " + _currentCount, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

```

### 3. Computed Properties (useComputed) ⚠️ Deprecated

Creates derived states computed based on other states. Recalculation occurs only when the dependent states change.

*Note:*
Under the severe CPU constraints of Garmin devices, the "dependency array (deps) change detection loop" performed internally by `useComputed` incurs noticeable overhead. Heavy use, especially near the rendering loop (`onUpdate`), can impact performance.

**✅ Recommended Alternative (Push-based + Manual Caching):**
Instead of this feature, we recommend using `watch` to detect changes in dependent states and manually performing recalculations and caching in class variables within the component.

```monkeyc
class BmiCalculator {
    function calcBmi(deps as Array) as Float {
        var w = deps[0].toFloat();
        var h = deps[1].toFloat() / 100.0;
        return (w / (h * h)).toFloat();
    }
}

var _bmiCalculator = new BmiCalculator();

class UserProfile {
    private var _weight = MonkeyHooks.useNumber(:weight).init(70);
    private var _height = MonkeyHooks.useNumber(:height).init(175);
    
    private var _bmi = MonkeyHooks.useComputed(
        :bmi,
        [:weight, :height],
        _bmiCalculator.method(:calcBmi)
    );

    function printBmi() {
        System.println("BMI: " + _bmi.req());
    }
}

```

### 4. Collection Type Operations and Forced Updates (forceSet)

By Monkey C specification, arrays and dictionaries are compared by reference (`!=`). Modifying the contents of an existing array and calling `set()` will not be detected as a change.
When directly manipulating elements, use `forceSet()` to bypass reference comparison and forcefully trigger an update.

```monkeyc
var arrHook = MonkeyHooks.useArray(:myList);
var list = arrHook.req();

list.add("New Item"); // Modifies the array contents (reference remains the same)

// arrHook.set(list); // Ignored because the reference is identical
arrHook.forceSet(list); // Forcefully triggers an update notification and re-render

```

### 5. Persistent Storage (useStorageString)

Integrates with `Application.Storage` to create states that persist even after the app is closed.

```monkeyc
var userName = MonkeyHooks.useStorageString("username").init("Guest");
userName.set("Bob"); // Updates the Store and executes Storage.setValue() simultaneously

```

*(Note: Do not read/write storage hooks inside `onUpdate` or high-frequency timers. This will shorten flash memory lifespan and critically degrade performance.)*

### 6. Resource Sharing (SharedTimer / LocationHook)

Safely share system resources. Resources start when the first listener is registered and automatically stop when listeners drop to zero.

```monkeyc
class MainView extends WatchUi.View {
    function onShow() {
        MonkeyHooks.SharedTimer.subscribe(self, :onTick);
        MonkeyHooks.LocationHook.subscribe(self, :onLocationUpdated);
    }

    function onTick() as Void { /* Processes at regular intervals */ }
    function onLocationUpdated(info as Position.Info) as Void { /* GPS processes */ }

    function onHide() {
        MonkeyHooks.SharedTimer.unsubscribe(self, :onTick);
        MonkeyHooks.LocationHook.unsubscribe(self, :onLocationUpdated);
    }
}

```

### 7. Routing (MonkeyRouter)

Manages the creation of Views and Delegates to handle screen transitions.

```monkeyc
function onStart(state) {
    MonkeyHooks.Router.initialize(method(:viewFactory));
}

function viewFactory(routeId as Number) as Array? {
    switch(routeId) {
        case 1: return [new HomeView(), new HomeDelegate()];
        case 2: return [new SettingsView(), null];
    }
    return null;
}

// Execute transition
MonkeyHooks.Router.push(1, WatchUi.SLIDE_LEFT);

```

### 8. Testing and Benchmarking (Test Utilities)

To fully leverage the architecture that separates "pure rendering" from "state management" on Garmin devices, MonkeyHooks provides test utilities.

You can run UI rendering tests (crash detection) and benchmark performance in the background without launching the simulator screen.

#### Basic Setup for Test Utilities

By accessing `MonkeyHooks.TestUtils` from within test code, you can reset the Store, inject mock states, and generate dummy canvases.

#### 1. Resetting Store and Mocking States

Cleans the globally held states per test and injects dummy data required for testing.

```monkeyc
import Toybox.Test;

(:test)
function testMyBusinessLogic(logger as Test.Logger) as Boolean {
    // 1. Reset the Store to prevent state pollution across tests
    MonkeyHooks.TestUtils.resetStore();

    // 2. Inject mock states required for testing (UI updates are not fired)
    MonkeyHooks.TestUtils.injectState({
        :counter => 10,
        "username" => "TestUser"
    });

    // 3. Execute and verify logic
    var counterHook = MonkeyHooks.useNumber(:counter);
    counterHook.set(counterHook.req() + 1);

    Test.assertEqualMessage(counterHook.req(), 11, "Counter should increment correctly");
    return true;
}

```

#### 2. Crash Testing Pure Render Modules (Smoke Test)

By passing a dummy array of arguments (Props) and a dummy canvas (Dc) to a pure render module created with the "Props Packing Pattern," you can safely test for crashes (thrown exceptions) in edge cases.

```monkeyc
import Toybox.Test;
import Toybox.Graphics;

(:test)
function testMainRenderDoesNotCrash(logger as Test.Logger) as Boolean {
    // 1. Get a dummy canvas (240x240) provided by the library
    var dc = MonkeyHooks.TestUtils.createDummyDc(240, 240);

    // 2. Create a dummy Props array containing abnormal values or edge cases
    var badProps = new [MainProps.DATA_SIZE];
    badProps[MainProps.W] = 240;
    badProps[MainProps.H] = 240;
    badProps[MainProps.TITLE_FONT] = null; // Case where font fails to load
    badProps[MainProps.PROGRESS] = -999.0; // Abnormal animation value
    // ...

    // 3. Execute rendering and verify it doesn't crash with an exception
    try {
        MainRender.render(dc, badProps);
        logger.debug("Render executed successfully.");
    } catch(e) {
        logger.error("Render crashed: " + e.getErrorMessage());
        return false;
    }

    return true;
}

```

#### 3. Benchmarking UI Rendering

Automatically measure and verify rendering speeds to check if they meet the strict CPU requirements of Garmin devices (e.g., less than 10ms per frame).

```monkeyc
import Toybox.Test;

(:test)
function benchmarkMainRender(logger as Test.Logger) as Boolean {
    var dc = MonkeyHooks.TestUtils.createDummyDc(240, 240);
    var props = [ /* ... Normal Props data ... */ ];
    
    // Execute the render function continuously for a specified number of times (e.g., 100) and measure execution time (ms)
    var totalTimeMs = MonkeyHooks.TestUtils.benchmarkRender(
        logger, 
        dc, 
        MainRender.method(:render), 
        props, 
        100, // Number of executions
        "MainView Render" // Name for the log
    );

    // Require the execution time for 100 frames to be under 1000ms (= under 10ms per frame)
    Test.assertEqualMessage(totalTimeMs < 1000, true, "Does not meet rendering performance requirements");

    return true;
}

```

---

## License

MIT License
Copyright (c) 2026 Ichimura Tomoo