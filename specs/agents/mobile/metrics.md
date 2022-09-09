## Mobile Metrics

### CPU metrics
| Name               | Type             | Units      | Description                     |
|--------------------|------------------|------------|---------------------------------|
| `system.cpu.usage` | Gauge | percentage | A percentage value of cpu usage |

### Memory Metrics
| Name                   | Type             | Units | Description                             |
|------------------------|------------------|-------|-----------------------------------------|
| `system.memory.usage`  | Observable Guage | bytes | The application's memory usage in bytes |


### Application Metrics
#### load times
| Name                                          | Type      | Units   | Description                                                           |
|-----------------------------------------------|-----------|---------|-----------------------------------------------------------------------|
| `application.launch.optimizedTimeToFirstDraw` | histogram | seconds | The amount of time spent launching the app until loaded (optimized)   |
| `application.launch.timeToFirstDraw`          | histogram | seconds | The amound of time spent launching the app until loaded               |
| `application.launch.resumeTime`               | histogram | seconds | the amount of time spent resuming the application from the background | 

#### responsiveness
| Name                                   | Type      | Units   | Description                                                 |
|----------------------------------------|-----------|---------|-------------------------------------------------------------|
|  `application.responsiveness.hangtime` | histogram | seconds | The amount of time the applications has spent unresponsive. | 
 
### Application exit
Traces application exit counts in both healthy and unhealthy (crashes) states

| Name               | Type  | Units | Description                   |
|--------------------|-------|-------|-------------------------------|
| `application.exit` | count |  unit | A count of application exits. |


| Labels     |  Values                                                                                        |  Description                                                                   | 
|------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------| 
| `appState` | `background`, `foreground`                                                                     | This denotes whether the application exited in the background or foreground    |
| `type`     | `memoryResourceLimit`, `AppWatchDog`, `BadAccess`, `Abnormal`,  `IllegalInstruction`, `Normal` | The cause of the application exit. All but normal could be considered a crash. |



