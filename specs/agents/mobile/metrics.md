## Mobile Metrics

### CPU metrics
| Name               | Type             | Units      | Description                     |
|--------------------|------------------|------------|---------------------------------|
| `system.cpu.usage` | Gauge | percentage | A percentage value of cpu usage |

### Memory Metrics
| Name                   | Type             | Units | Description                             |
|------------------------|------------------|-------|-----------------------------------------|
| `system.memory.usage`  | Gauge | bytes | The application's memory usage in bytes |


### Application Metrics
#### load times
| Name                                 | Type      | Units   | Description                                                           |
|--------------------------------------|-----------|---------|-----------------------------------------------------------------------|
| `application.launch.time`            | histogram | milliseconds | The amount of time spent launching the app                            |

| Labels | Values                                          | Description                                         |
|--------|-------------------------------------------------|-----------------------------------------------------|
| `type` | `first draw`, `first draw (optimized)`, `resume`| The type of application launch that is being timed. |

#### responsiveness
| Name                                   | Type      | Units   | Description                                                 |
|----------------------------------------|-----------|---------|-------------------------------------------------------------|
|  `application.responsiveness.hangtime` | histogram | millisseconds | The amount of time the applications has spent unresponsive. | 
 
### Application exit
Traces application exit counts in both healthy and unhealthy (crashes) states

| Name                | Type  | Units | Description                   |
|---------------------|-------|-------|-------------------------------|
| `application.exits` | count |  unit | A count of application exits. |


| Labels     |  Values                                                                                        |  Description                                                                   |
|------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `appState` | `background`, `foreground`                                                                     | This denotes whether the application exited in the background or foreground    |
| `type`     | `memoryResourceLimit`, `AppWatchDog`, `BadAccess`, `Abnormal`,  `IllegalInstruction`, `Normal` | The cause of the application exit. All but normal could be considered a crash. |



