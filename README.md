# VOGDataExplorer
Is a tool to visualize vog data with eye and head movement recordings and mark different types of events on them. Either a Time column or the samplerate has to be provided

```
app = VOGDataExplorer.MarkData(data)
app = VOGDataExplorer.MarkData(data, samplerate)
app = VOGDataExplorer.MarkData(xdata, ydata, samplerate)
app = VOGDataExplorer.MarkData(leftxdata, leftydata, rightxdata, rightydata, samplerate)
app = VOGDataExplorer.MarkData( ...
		   table(  datacolumn1, datacolumn2,(...), ...
				   'VariableNames', ...
				   {'nameColumn1', 'nameColumn2', (...));

All those options can be also used with a different method:
app = VOGDataExplorer.Open(data)
app = VOGDataExplorer.Open ...

data = VOGDataExplorer.MarkData(...) this will block until
	   UI is closed

Inputs:
   - data: data table, should contain some of these columns
			   - Time: timestamps in seconds
			   - LeftX : left eye horizontal eye position
			   - LeftY : left eye vertical eye position
			   - LeftT : left eye torsional eye position
			   - RightX : right eye horizontal eye position
			   - RightY : right eye vertical eye position
			   - RightT : right eye torsional eye position
			   - LeftVelX : left eye horizontal eye velocity
			   - LeftVelY : left eye vertical eye velocity
			   - LeftVelT : left eye torsional eye velocity
			   - RightVelX : right eye horizontal eye velocity
			   - RightVelY : right eye vertical eye velocity
			   - RightVelT : right eye torsional eye velocity

			   - HeadX : head horizontal (yaw) position
			   - HeadY : head vertica (pitch) position
			   - HeadT : head torsional (roll) position
			   - HeadVelX : head horizontal (yaw) velocity
			   - HeadVelY : head vertica (pitch) velocity
			   - HeadVelT : head torsional (roll) velocity

			   - TargetX : target horizontal position (deg)
			   - TargetY : target horizontal position (deg)
			   - TargetT : target torsional position (deg);
			   -
			   - QuickPhase : boolean column indicating if
				   a sample belongs to a quick phase/
				   saccade
			   - SlowPhase : boolean column indicating if
				   a sample belongs to a slow phase
			   - HeadImpule : boolean column indicating if
				   a sample belongs to a head impulse
			   - BadData : boolean column indicating if
				   a sample belongs to a period of bad
				   data, i.e. due to blink

   - samplerate: samplerate of the data (not necessary if
   there is time)
   - xdata: column vector with the horizontal eye data
   - ydata: column vector with the vertical eye data

Outputs:
   - app: VOGDataExplorer object
   - app.data: updated data table including boolean
		   columns for marks
      
```
