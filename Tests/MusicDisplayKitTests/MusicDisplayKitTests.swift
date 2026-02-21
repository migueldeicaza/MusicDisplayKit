import Foundation
import Testing
import ZIPFoundation

@testable import MusicDisplayKit
import MusicDisplayKitCore
import MusicDisplayKitLayout
import MusicDisplayKitModel
import MusicDisplayKitMusicXML
import MusicDisplayKitVexAdapter
import VexFoundation
#if canImport(SwiftUI)
import SwiftUI
#endif

private let minimalScoreXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work>
    <work-title>Prelude in C</work-title>
  </work>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1"></measure>
    <measure number="2"></measure>
  </part>
</score-partwise>
"""

private let movementTitleFallbackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <movement-title>Etude</movement-title>
  <part-list>
    <score-part id="Solo">
      <part-name>Solo</part-name>
    </score-part>
  </part-list>
  <part id="Solo">
    <measure></measure>
  </part>
</score-partwise>
"""

private let layoutTimeSignatureSpacingXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
    </measure>
    <measure number="2">
      <attributes>
        <time><beats>2</beats><beat-type>4</beat-type></time>
      </attributes>
    </measure>
    <measure number="3">
      <attributes>
        <time><beats>6</beats><beat-type>8</beat-type></time>
      </attributes>
    </measure>
  </part>
</score-partwise>
"""

private let multiPartLayoutSynchronizationXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <part-group type="start" number="1">
      <group-symbol>brace</group-symbol>
      <group-name>Grand Staff</group-name>
      <group-barline>yes</group-barline>
    </part-group>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
    <score-part id="P2"><part-name>Violin</part-name></score-part>
    <part-group type="stop" number="1"/>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    </measure>
    <measure number="2">
      <attributes><time><beats>2</beats><beat-type>4</beat-type></time></attributes>
    </measure>
    <measure number="3">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    </measure>
  </part>
  <part id="P2">
    <measure number="1">
      <attributes><time><beats>3</beats><beat-type>4</beat-type></time></attributes>
    </measure>
    <measure number="2">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    </measure>
    <measure number="3">
      <attributes><time><beats>2</beats><beat-type>4</beat-type></time></attributes>
    </measure>
  </part>
</score-partwise>
"""

private let nestedPartGroupLayoutXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <part-group type="start" number="1">
      <group-symbol>bracket</group-symbol>
      <group-name>Ensemble</group-name>
      <group-barline>yes</group-barline>
    </part-group>
    <part-group type="start" number="2">
      <group-symbol>brace</group-symbol>
      <group-name>Manuals</group-name>
      <group-barline>no</group-barline>
    </part-group>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
    <score-part id="P2"><part-name>Part 2</part-name></score-part>
    <part-group type="stop" number="2"/>
    <score-part id="P3"><part-name>Part 3</part-name></score-part>
    <part-group type="stop" number="1"/>
  </part-list>
  <part id="P1">
    <measure number="1"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
    <measure number="2"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
  </part>
  <part id="P2">
    <measure number="1"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
    <measure number="2"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
  </part>
  <part id="P3">
    <measure number="1"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
    <measure number="2"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
  </part>
</score-partwise>
"""

private let sameSpanPartGroupOrderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <part-group type="start" number="1">
      <group-symbol>bracket</group-symbol>
      <group-barline>yes</group-barline>
    </part-group>
    <part-group type="start" number="2">
      <group-symbol>brace</group-symbol>
      <group-barline>no</group-barline>
    </part-group>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
    <score-part id="P2"><part-name>Part 2</part-name></score-part>
    <part-group type="stop" number="2"/>
    <part-group type="stop" number="1"/>
  </part-list>
  <part id="P1">
    <measure number="1"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
  </part>
  <part id="P2">
    <measure number="1"><attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes></measure>
  </part>
</score-partwise>
"""

private let noteVoiceTimingXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
      </attributes>
      <note>
        <pitch>
          <step>C</step>
          <alter>1</alter>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <backup>
        <duration>4</duration>
      </backup>
      <note>
        <rest/>
        <duration>4</duration>
        <voice>2</voice>
      </note>
      <forward>
        <duration>2</duration>
      </forward>
      <note>
        <grace/>
        <chord/>
        <pitch>
          <step>D</step>
          <octave>5</octave>
        </pitch>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let singleVoiceRenderNotesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Solo</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <rest/>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <pitch><step>E</step><alter>1</alter><octave>4</octave></pitch>
        <duration>8</duration>
        <voice>1</voice>
      </note>
      <backup><duration>16</duration></backup>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch>
        <duration>16</duration>
        <voice>2</voice>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>16</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let multiVoiceChordRenderNotesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Solo</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <chord/>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <rest/>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <backup><duration>8</duration></backup>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch>
        <duration>8</duration>
        <voice>2</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let beamTupletRenderNotesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Solo</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>8</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <beam number="1">begin</beam>
        <notations><tuplet type="start" number="1" bracket="yes" placement="above" show-number="both"/></notations>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <beam number="1">continue</beam>
        <notations><tuplet type="continue" number="1"/></notations>
      </note>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <type>eighth</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <beam number="1">end</beam>
        <notations><tuplet type="stop" number="1"/></notations>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let measureAttributesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="10">
      <attributes>
        <divisions>8</divisions>
        <key>
          <fifths>-3</fifths>
          <mode>minor</mode>
        </key>
        <time symbol="common">
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef number="1">
          <sign>G</sign>
          <line>2</line>
        </clef>
        <clef number="2">
          <sign>F</sign>
          <line>4</line>
          <clef-octave-change>-1</clef-octave-change>
        </clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>8</duration>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let lyricTieSlurXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Voice</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>2</duration>
        <voice>1</voice>
        <tie type="start"/>
        <notations>
          <tied type="start"/>
          <slur type="start" number="1" placement="above"/>
        </notations>
        <lyric number="1">
          <syllabic>begin</syllabic>
          <text>Hel</text>
        </lyric>
      </note>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>2</duration>
        <voice>1</voice>
        <tie type="stop"/>
        <notations>
          <tied type="stop"/>
          <slur type="stop" number="1"/>
        </notations>
        <lyric number="1">
          <syllabic>end</syllabic>
          <text>lo</text>
          <extend/>
        </lyric>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let crossMeasureLyricsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Voice</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <lyric number="1">
          <syllabic>begin</syllabic>
          <text>Hal</text>
        </lyric>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <lyric number="1">
          <syllabic>end</syllabic>
          <text>lo</text>
        </lyric>
      </note>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <lyric number="1">
          <text>there</text>
          <extend/>
        </lyric>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let lyricExtenderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Voice</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <voice>1</voice>
        <lyric number="1">
          <text>A</text>
          <extend/>
        </lyric>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>1</duration>
        <voice>1</voice>
      </note>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>1</duration>
        <voice>1</voice>
      </note>
      <note>
        <pitch><step>F</step><octave>4</octave></pitch>
        <duration>1</duration>
        <voice>1</voice>
        <lyric number="1">
          <text>men</text>
        </lyric>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let multiVoiceLyricsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Voice</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <lyric number="1">
          <text>High</text>
        </lyric>
      </note>
      <backup>
        <duration>4</duration>
      </backup>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch>
        <duration>4</duration>
        <voice>2</voice>
        <lyric number="1">
          <text>Low</text>
        </lyric>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let crossMeasureSlurXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Violin</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <notations>
          <slur type="start" number="3" placement="above"/>
        </notations>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>A</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <notations>
          <slur type="stop" number="3"/>
        </notations>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let beamTupletXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>8</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <beam number="1">begin</beam>
        <notations>
          <tuplet type="start" number="1" bracket="yes" placement="below" show-number="both" show-type="actual"/>
        </notations>
        <time-modification>
          <actual-notes>3</actual-notes>
          <normal-notes>2</normal-notes>
        </time-modification>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
        <beam number="1">end</beam>
        <notations>
          <tuplet type="stop" number="1"/>
        </notations>
        <time-modification>
          <actual-notes>3</actual-notes>
          <normal-notes>2</normal-notes>
        </time-modification>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let articulationsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>4</duration>
        <notations>
          <articulations>
            <staccato placement="above"/>
            <strong-accent type="up"/>
          </articulations>
        </notations>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let directionExpressionsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <direction placement="above">
        <direction-type>
          <metronome parentheses="yes">
            <beat-unit>quarter</beat-unit>
            <beat-unit-dot/>
            <per-minute>120</per-minute>
          </metronome>
          <dynamics>
            <mf/>
          </dynamics>
          <words>dolce</words>
          <rehearsal>A</rehearsal>
          <wedge type="crescendo" number="1" spread="12" niente="no" line-type="solid"/>
          <octave-shift type="up" number="1" size="8"/>
          <pedal type="start" line="yes" sign="no"/>
        </direction-type>
        <sound tempo="120"/>
        <offset>2</offset>
        <staff>1</staff>
      </direction>
      <note>
        <rest/>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let directionRenderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction placement="above">
        <direction-type>
          <dynamics>
            <mf/>
          </dynamics>
          <words>dolce</words>
          <rehearsal>A</rehearsal>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let directionDynamicDefaultPlacementXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction>
        <direction-type>
          <dynamics>
            <mf/>
          </dynamics>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let directionSpanRenderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction placement="below">
        <direction-type>
          <wedge type="crescendo" number="1"/>
          <pedal type="start" line="yes" sign="no"/>
        </direction-type>
      </direction>
      <direction placement="above">
        <direction-type>
          <octave-shift type="up" number="1" size="8"/>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <direction placement="below">
        <direction-type>
          <wedge type="stop" number="1"/>
          <pedal type="stop" line="yes" sign="no"/>
        </direction-type>
      </direction>
      <direction placement="above">
        <direction-type>
          <octave-shift type="stop" number="1" size="8"/>
        </direction-type>
      </direction>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let directionTempoRenderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction placement="above">
        <direction-type>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <beat-unit-dot/>
            <per-minute>120</per-minute>
          </metronome>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <direction placement="above">
        <sound tempo="96"/>
      </direction>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let harmonyXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <harmony>
        <root>
          <root-step>C</root-step>
          <root-alter>1</root-alter>
        </root>
        <kind text="maj7" use-symbols="yes">major-seventh</kind>
        <degree>
          <degree-value>9</degree-value>
          <degree-alter>-1</degree-alter>
          <degree-type>add</degree-type>
        </degree>
        <offset>2</offset>
        <staff>1</staff>
      </harmony>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let harmonyFormattingXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <harmony>
        <root>
          <root-step>F</root-step>
          <root-alter>1</root-alter>
        </root>
        <kind>minor-seventh</kind>
        <bass>
          <bass-step>C</bass-step>
          <bass-alter>-1</bass-alter>
        </bass>
      </harmony>
      <note>
        <pitch><step>F</step><alter>1</alter><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatsAndTempoXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <direction placement="above">
        <sound tempo="96"/>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <barline location="right">
        <ending number="1" type="start"/>
      </barline>
    </measure>
    <measure number="2">
      <direction placement="above">
        <direction-type>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <per-minute>72</per-minute>
          </metronome>
          <segno/>
          <coda/>
          <words>To Coda</words>
          <words>Fine</words>
        </direction-type>
        <sound dacapo="yes" dalsegno="seg1" tocoda="coda1" fine="Fine"/>
      </direction>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <barline location="right">
        <repeat direction="backward" times="2"/>
        <ending number="1" type="stop"/>
      </barline>
    </measure>
  </part>
</score-partwise>
"""

private let tempoTimelineFromTimeSignatureXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time>
          <beats>3</beats>
          <beat-type>4</beat-type>
        </time>
      </attributes>
      <direction>
        <sound tempo="90"/>
      </direction>
    </measure>
    <measure number="2">
      <direction>
        <sound tempo="110"/>
      </direction>
    </measure>
  </part>
</score-partwise>
"""

private let repeatEndingPlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <ending number="1" type="start"/>
        <ending number="1" type="stop"/>
        <repeat direction="backward"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <barline location="left">
        <ending number="2" type="start"/>
        <ending number="2" type="stop"/>
      </barline>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let sequentialImplicitRepeatStartXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <barline location="right">
        <repeat direction="backward"/>
      </barline>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatTimesAttributePlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward" times="3"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatTimesOnePlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward" times="1"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatTimesZeroPlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward" times="0"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatTimesNegativePlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward" times="-2"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let repeatTimesDefaultPlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="right">
        <repeat direction="backward"/>
      </barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let endingWithoutBackwardRepeatXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <ending number="2" type="start"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      <barline location="right">
        <ending number="2" type="stop"/>
      </barline>
    </measure>
    <measure number="2">
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoAlCodaPlaybackXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction>
        <direction-type>
          <words>D.S.</words>
          <words>al Coda</words>
        </direction-type>
      </direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction><direction-type><words>To Coda</words></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><coda/></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let targetedDalSegnoToCodaXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno>A</segno></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction><direction-type><segno>B</segno></direction-type></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction>
        <direction-type>
          <words>D.S. al Coda</words>
        </direction-type>
        <sound dalsegno="B" tocoda="C2"/>
      </direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><words>To Coda</words></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="5">
      <direction><direction-type><coda>C1</coda></direction-type></direction>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="6">
      <direction><direction-type><coda>C2</coda></direction-type></direction>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoPrecedenceOverDaCapoXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction>
        <direction-type>
          <words>D.S.</words>
          <words>D.C.</words>
          <words>al Fine</words>
        </direction-type>
        <sound dacapo="yes" dalsegno="S3"/>
      </direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction><direction-type><segno>S3</segno></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><words>Fine</words></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let endingNumberRangeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <barline location="left">
        <ending number="1-3, 5 + 7" type="start"/>
      </barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      <barline location="right">
        <ending number="1-3, 5 + 7" type="stop"/>
      </barline>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoAlCodaIgnoresFineXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction><direction-type><words>D.S. al Coda</words></direction-type></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction>
        <direction-type>
          <words>Fine</words>
          <words>To Coda</words>
        </direction-type>
      </direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><coda/></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoAlCodaUsesForwardCodaXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><coda/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction><direction-type><segno/></direction-type></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction><direction-type><words>D.S. al Coda</words></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><words>To Coda</words></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="5">
      <direction><direction-type><coda/></direction-type></direction>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoAlCodaToCodaOnJumpMeasureXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction>
        <direction-type>
          <words>D.S. al Coda</words>
          <words>To Coda</words>
        </direction-type>
      </direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><coda/></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let dalSegnoAlCodaWithRepeatEndingsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno>S</segno></direction-type></direction>
      <barline location="left"><repeat direction="forward"/></barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <barline location="left"><ending number="1" type="start"/></barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <barline location="right">
        <ending number="1" type="stop"/>
        <repeat direction="backward"/>
      </barline>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <barline location="left"><ending number="2" type="start"/></barline>
      <direction><direction-type><words>To Coda</words></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
      <barline location="right"><ending number="2" type="stop"/></barline>
    </measure>
    <measure number="5">
      <direction><direction-type><coda>C</coda></direction-type></direction>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="6">
      <direction>
        <direction-type><words>D.S. al Coda</words></direction-type>
        <sound dalsegno="S" tocoda="C"/>
      </direction>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let targetedToCodaDoesNotFallbackToDifferentCodaXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno>S</segno></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction>
        <direction-type><words>D.S. al Coda</words></direction-type>
        <sound dalsegno="S" tocoda="C2"/>
      </direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <direction><direction-type><words>To Coda</words></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="5">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="6">
      <direction><direction-type><coda>C1</coda></direction-type></direction>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let soundToCodaFallbackOnJumpMeasureXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><segno>S</segno></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <direction>
        <direction-type><words>D.S. al Coda</words></direction-type>
        <sound dalsegno="S" tocoda="C"/>
      </direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <direction><direction-type><coda>C</coda></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private let instrumentTraversalXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
    <score-part id="P2"><part-name>Violin</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
  <part id="P2">
    <measure number="1">
      <attributes>
        <divisions>8</divisions>
      </attributes>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>8</duration></note>
    </measure>
  </part>
</score-partwise>
"""

private func makeMXLArchiveData(
    rootfilePath: String = "score.musicxml",
    rootfileXML: String = minimalScoreXML
) throws -> Data {
    let containerXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="\(rootfilePath)" media-type="application/vnd.recordare.musicxml+xml"/>
      </rootfiles>
    </container>
    """

    let archive = try Archive(data: Data(), accessMode: .create)
    try addFileEntry(data: Data(containerXML.utf8), path: "META-INF/container.xml", to: archive)
    try addFileEntry(data: Data(rootfileXML.utf8), path: rootfilePath, to: archive)
    guard let data = archive.data else {
        throw MusicXMLDocumentLoaderError.invalidMXLArchive
    }
    return data
}

private func osmdFixtureURL(named filename: String) throws -> URL {
    let fileManager = FileManager.default

    let cwdCandidate = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("../opensheetmusicdisplay/test/data/\(filename)")
        .standardizedFileURL
    if fileManager.fileExists(atPath: cwdCandidate.path) {
        return cwdCandidate
    }

    let testFileURL = URL(fileURLWithPath: #filePath, isDirectory: false)
    let packageRootCandidate = testFileURL
        .deletingLastPathComponent() // MusicDisplayKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // MusicDisplayKit
        .appendingPathComponent("opensheetmusicdisplay/test/data/\(filename)")
        .standardizedFileURL
    if fileManager.fileExists(atPath: packageRootCandidate.path) {
        return packageRootCandidate
    }

    throw NSError(
        domain: "MusicDisplayKitTests",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find OSMD fixture: \(filename)"]
    )
}

private func addFileEntry(data: Data, path: String, to archive: Archive) throws {
    try archive.addEntry(
        with: path,
        type: .file,
        uncompressedSize: Int64(data.count),
        compressionMethod: .deflate,
        provider: { position, size in
            let start = Int(position)
            guard start < data.count else {
                return Data()
            }
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    )
}

private struct TitleSuffixModule: AfterScoreReadingModule {
    let suffix: String

    func process(score: inout Score) throws {
        score.title += suffix
    }
}

private struct NoOpScoreRenderer: ScoreRenderer {
    func render(_ score: LaidOutScore, target: RenderTarget) throws {}
}

private let pngSignaturePrefix: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

@Test func renderWithoutLoadThrows() throws {
    let engine = MusicDisplayEngine()

    #expect(throws: MusicDisplayEngineError.noScoreLoaded) {
        try engine.render(target: .view(identifier: "preview"))
    }
}

@Test func parserReadsTitlePartsAndMeasures() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    #expect(score.title == "Prelude in C")
    #expect(score.parts.count == 1)
    #expect(score.parts.first?.id == "P1")
    #expect(score.parts.first?.name == "Piano")
    #expect(score.parts.first?.measures.map(\.number) == [1, 2])
}

@Test func parserFallsBackToMovementTitleAndAutoMeasureNumber() throws {
    let score = try MusicXMLParser().parse(xml: movementTitleFallbackXML)
    #expect(score.title == "Etude")
    #expect(score.parts.first?.measures.first?.number == 1)
}

@Test func parserReadsPartGroupMetadata() throws {
    let score = try MusicXMLParser().parse(xml: multiPartLayoutSynchronizationXML)
    #expect(score.partGroups.count == 1)

    let group = score.partGroups[0]
    #expect(group.number == 1)
    #expect(group.startPartID == "P1")
    #expect(group.endPartID == "P2")
    #expect(group.symbol == .brace)
    #expect(group.barline == true)
    #expect(group.name == "Grand Staff")
}

@Test func parserReadsNestedPartGroups() throws {
    let score = try MusicXMLParser().parse(xml: nestedPartGroupLayoutXML)
    #expect(score.partGroups.count == 2)

    let ensemble = try #require(score.partGroups.first(where: { $0.number == 1 }))
    #expect(ensemble.startPartID == "P1")
    #expect(ensemble.endPartID == "P3")
    #expect(ensemble.symbol == .bracket)
    #expect(ensemble.barline == true)

    let manuals = try #require(score.partGroups.first(where: { $0.number == 2 }))
    #expect(manuals.startPartID == "P1")
    #expect(manuals.endPartID == "P2")
    #expect(manuals.symbol == .brace)
    #expect(manuals.barline == false)
}

@Test func parserReadsUTF16EncodedData() throws {
    let utf16Body = try #require(minimalScoreXML.data(using: .utf16LittleEndian))
    var utf16Data = Data([0xFF, 0xFE])
    utf16Data.append(utf16Body)
    let score = try MusicXMLParser().parse(data: utf16Data, pathExtension: "musicxml")
    #expect(score.title == "Prelude in C")
    #expect(score.parts.first?.id == "P1")
}

@Test func parserReadsMXLDataViaContainerRootfile() throws {
    let mxlData = try makeMXLArchiveData(
        rootfilePath: "scores/main.musicxml",
        rootfileXML: minimalScoreXML
    )
    let score = try MusicXMLParser().parse(data: mxlData, pathExtension: "mxl")
    #expect(score.title == "Prelude in C")
    #expect(score.parts.first?.measures.map(\.number) == [1, 2])
}

@Test func parserFailsForMXLWithoutContainer() throws {
    let archive = try Archive(data: Data(), accessMode: .create)
    try addFileEntry(data: Data(minimalScoreXML.utf8), path: "score.musicxml", to: archive)
    let data = try #require(archive.data)

    #expect(throws: MusicXMLParserError.parserFailure("MXL container is missing META-INF/container.xml.")) {
        _ = try MusicXMLParser().parse(data: data, pathExtension: "mxl")
    }
}

@Test func loaderParsesFromXMLStringSource() throws {
    let loader = MusicXMLLoader()
    let score = try loader.loadScore(from: .xmlString(minimalScoreXML))
    #expect(score.title == "Prelude in C")
}

@Test func loaderParsesFromDataSourceWithExtensionHint() throws {
    let data = try makeMXLArchiveData()
    let loader = MusicXMLLoader()
    let score = try loader.loadScore(from: .data(data, pathExtension: "mxl"))
    #expect(score.parts.first?.id == "P1")
}

@Test func loaderParsesFromFileURLSource() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("musicxml")
    defer { try? FileManager.default.removeItem(at: tmpURL) }
    try Data(minimalScoreXML.utf8).write(to: tmpURL)

    let loader = MusicXMLLoader()
    let score = try loader.loadScore(from: .fileURL(tmpURL))
    #expect(score.title == "Prelude in C")
}

@Test func loaderRejectsUnsupportedURLScheme() throws {
    let loader = MusicXMLLoader()
    let ftpURL = try #require(URL(string: "ftp://example.com/score.musicxml"))
    #expect(throws: MusicXMLLoaderError.unsupportedURLScheme("ftp")) {
        _ = try loader.loadScore(from: .url(ftpURL))
    }
}

@Test func musicSheetReaderReadsFromSource() throws {
    let reader = MusicSheetReader()
    let score = try reader.read(from: .xmlString(minimalScoreXML))
    #expect(score.title == "Prelude in C")
}

@Test func musicSheetReaderRunsAfterReadingModules() throws {
    let reader = MusicSheetReader(
        afterReadingModules: [TitleSuffixModule(suffix: " (Ported)")]
    )
    let score = try reader.read(xml: minimalScoreXML)
    #expect(score.title == "Prelude in C (Ported)")
}

@Test func instrumentReaderTraversesMeasuresWithCarryForwardState() throws {
    let score = try MusicXMLParser().parse(xml: instrumentTraversalXML)
    let visits = InstrumentReader().readMeasureVisits(from: score)
    #expect(visits.count == 3)

    let p1m1 = visits[0]
    #expect(p1m1.partID == "P1")
    #expect(p1m1.measureNumber == 1)
    #expect(p1m1.effectiveDivisions == 4)
    #expect(p1m1.effectiveAttributes?.time == TimeSignature(beats: 4, beatType: 4))

    let p1m2 = visits[1]
    #expect(p1m2.partID == "P1")
    #expect(p1m2.measureNumber == 2)
    #expect(p1m2.effectiveDivisions == 4)
    #expect(p1m2.effectiveAttributes?.key == KeySignature(fifths: 0, mode: nil))

    let p2m1 = visits[2]
    #expect(p2m1.partID == "P2")
    #expect(p2m1.measureNumber == 1)
    #expect(p2m1.effectiveDivisions == 8)
    #expect(p2m1.effectiveAttributes?.time == nil)
}

@Test func voiceGeneratorBuildsEntriesAndSpans() throws {
    let score = try MusicXMLParser().parse(xml: beamTupletXML)
    let voiceMeasures = VoiceGenerator().generate(from: score)
    #expect(voiceMeasures.count == 1)

    let voice = try #require(voiceMeasures.first)
    #expect(voice.voice == 1)
    #expect(voice.entries.count == 2)
    #expect(voice.entries.map(\.onsetDivisions) == [0, 4])
    #expect(voice.beamSpans == [
        VoiceBeamSpan(number: 1, startEntryIndex: 0, endEntryIndex: 1)
    ])
    #expect(voice.tupletSpans == [
        VoiceTupletSpan(number: 1, startEntryIndex: 0, endEntryIndex: 1)
    ])
}

@Test func voiceGeneratorGroupsChordOnsetPerVoice() throws {
    let score = try MusicXMLParser().parse(xml: noteVoiceTimingXML)
    let voiceMeasures = VoiceGenerator().generate(from: score)
    #expect(voiceMeasures.count == 2)

    let voice1 = try #require(voiceMeasures.first(where: { $0.voice == 1 }))
    #expect(voice1.entries.count == 1)
    #expect(voice1.entries[0].onsetDivisions == 0)
    #expect(voice1.entries[0].noteIndices == [0, 2])
    #expect(voice1.entries[0].durationDivisions == 4)
}

@Test func voiceGeneratorMapsTieAndSlurSpans() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let voice = try #require(VoiceGenerator().generate(from: score).first)
    #expect(voice.entries.count == 2)
    #expect(voice.tieSpans.count == 1)
    #expect(voice.tieSpans[0].startEntryIndex == 0)
    #expect(voice.tieSpans[0].endEntryIndex == 1)
    #expect(voice.slurSpans.count == 1)
    #expect(voice.slurSpans[0].startEntryIndex == 0)
    #expect(voice.slurSpans[0].endEntryIndex == 1)
}

@Test func slurGeneratorBuildsCrossMeasureSlurEvents() throws {
    let score = try MusicXMLParser().parse(xml: crossMeasureSlurXML)
    let slurs = SlurGenerator().generate(from: score)
    #expect(slurs.count == 1)

    let slur = slurs[0]
    #expect(slur.number == 3)
    #expect(slur.placement == "above")
    #expect(slur.voice == 1)
    #expect(slur.startMeasureNumber == 1)
    #expect(slur.endMeasureNumber == 2)
    #expect(slur.spansMultipleMeasures == true)
    #expect(slur.isOpenEnded == false)
}

@Test func lyricsGeneratorBuildsInMeasureWords() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let words = LyricsGenerator().generate(from: score)
    #expect(words.count == 1)
    #expect(words[0].text == "Hello")
    #expect(words[0].usesHyphen == true)
    #expect(words[0].hasExtension == true)
    #expect(words[0].spansMultipleMeasures == false)
}

@Test func lyricsGeneratorBuildsCrossMeasureWords() throws {
    let score = try MusicXMLParser().parse(xml: crossMeasureLyricsXML)
    let words = LyricsGenerator().generate(from: score)
    #expect(words.count == 2)

    let first = words[0]
    #expect(first.text == "Hallo")
    #expect(first.usesHyphen == true)
    #expect(first.spansMultipleMeasures == true)
    #expect(first.startMeasureNumber == 1)
    #expect(first.endMeasureNumber == 2)

    let second = words[1]
    #expect(second.text == "there")
    #expect(second.usesHyphen == false)
    #expect(second.hasExtension == true)
    #expect(second.spansMultipleMeasures == false)
}

@Test func chordSymbolGeneratorFormatsHarmonyEvents() throws {
    let score = try MusicXMLParser().parse(xml: harmonyXML)
    let events = ChordSymbolGenerator().generate(from: score)
    #expect(events.count == 1)
    #expect(events[0].displayText == "C#maj7(addb9)")
}

@Test func chordSymbolGeneratorFormatsKindAndBassFallback() throws {
    let score = try MusicXMLParser().parse(xml: harmonyFormattingXML)
    let events = ChordSymbolGenerator().generate(from: score)
    #expect(events.count == 1)
    #expect(events[0].displayText == "F#m7/Cb")
}

@Test func articulationGeneratorBuildsEventsFromNotes() throws {
    let score = try MusicXMLParser().parse(xml: articulationsXML)
    let events = ArticulationGenerator().generate(from: score)
    #expect(events.count == 2)
    #expect(events[0].kind == .staccato)
    #expect(events[0].placement == "above")
    #expect(events[1].kind == .strongAccent)
    #expect(events[1].type == "up")
}

@Test func expressionGeneratorBuildsEventsFromDirections() throws {
    let score = try MusicXMLParser().parse(xml: directionExpressionsXML)
    let events = ExpressionGenerator().generate(from: score)
    #expect(events.count == 8)

    #expect(events.contains {
        if case .dynamic("mf") = $0.value {
            return true
        }
        return false
    })
    #expect(events.contains {
        if case .words("dolce") = $0.value {
            return true
        }
        return false
    })
    #expect(events.contains {
        if case .rehearsal("A") = $0.value {
            return true
        }
        return false
    })
    #expect(events.contains {
        if case .soundTempo(120) = $0.value {
            return true
        }
        return false
    })
    #expect(events.contains {
        if case .metronome(MetronomeMark(beatUnit: "quarter", beatUnitDotCount: 1, perMinute: "120", parentheses: true)) = $0.value {
            return true
        }
        return false
    })
}

@Test func expressionGeneratorIncludesRoadmapRepetitionEvents() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let events = ExpressionGenerator().generate(from: score)
    let instructions = events.compactMap { event -> RepetitionInstruction? in
        if case .repetition(let instruction) = event.value {
            return instruction
        }
        return nil
    }

    #expect(instructions.contains { $0.kind == .segno })
    #expect(instructions.contains { $0.kind == .coda })
    #expect(instructions.contains { $0.kind == .daCapo })
    #expect(instructions.contains { $0.kind == .dalSegno && $0.target == "seg1" })
    #expect(instructions.contains { $0.kind == .toCoda && $0.target == "coda1" })
    #expect(instructions.contains { $0.kind == .alCoda && $0.target == "coda1" })
    #expect(instructions.contains { $0.kind == .alFine })
    #expect(instructions.contains { $0.kind == .fine })
}

@Test func tempoTimelineGeneratorBuildsAbsolutePositionsFromMeasures() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let events = TempoTimelineGenerator().generate(from: score)

    #expect(events.count == 4)
    #expect(events[0].source == .carryForward)
    #expect(events[0].absolutePosition == MDKFraction(0, 1))
    #expect(events[1].source == .sound)
    #expect(events[1].absolutePosition == MDKFraction(0, 1))
    #expect(events[2].source == .carryForward)
    #expect(events[2].absolutePosition == MDKFraction(1, 4))
    #expect(events[3].source == .metronome)
    #expect(events[3].absolutePosition == MDKFraction(1, 4))
}

@Test func tempoTimelineGeneratorUsesTimeSignatureForEmptyMeasures() throws {
    let score = try MusicXMLParser().parse(xml: tempoTimelineFromTimeSignatureXML)
    let events = TempoTimelineGenerator().generate(from: score)
    #expect(events.count == 4)

    let measure2Events = events.filter { $0.measureNumber == 2 && $0.source != .carryForward }
    #expect(measure2Events.count == 1)
    #expect(measure2Events[0].absolutePosition == MDKFraction(3, 4))
    #expect(measure2Events[0].bpm == 110)
}

@Test func musicSheetReaderReadWithTraversalReturnsInstrumentVisits() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(instrumentTraversalXML))
    #expect(result.score.parts.count == 2)
    #expect(result.instrumentMeasureVisits.map(\.partID) == ["P1", "P1", "P2"])
    #expect(result.instrumentMeasureVisits.map(\.measureNumber) == [1, 2, 1])
    #expect(result.voiceMeasures.map(\.voice) == [1, 1, 1])
    #expect(result.chordSymbols.isEmpty)
    #expect(result.articulationEvents.isEmpty)
    #expect(result.expressionEvents.isEmpty)
    #expect(result.slurEvents.isEmpty)
    #expect(!result.tempoTimelineEvents.isEmpty)
}

@Test func musicSheetReaderReadWithTraversalIncludesChordSymbols() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(harmonyXML))
    #expect(result.chordSymbols.count == 1)
    #expect(result.chordSymbols[0].displayText == "C#maj7(addb9)")
    #expect(result.articulationEvents.isEmpty)
    #expect(result.expressionEvents.isEmpty)
    #expect(result.slurEvents.isEmpty)
    #expect(result.tempoTimelineEvents.count == 1)
}

@Test func musicSheetReaderReadWithTraversalIncludesArticulations() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(articulationsXML))
    #expect(result.articulationEvents.count == 2)
    #expect(result.articulationEvents.map(\.kind) == [.staccato, .strongAccent])
    #expect(result.lyricWordEvents.isEmpty)
    #expect(result.expressionEvents.isEmpty)
    #expect(result.slurEvents.isEmpty)
    #expect(result.tempoTimelineEvents.count == 1)
}

@Test func musicSheetReaderReadWithTraversalIncludesLyricWords() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(crossMeasureLyricsXML))
    #expect(result.lyricWordEvents.count == 2)
    #expect(result.lyricWordEvents[0].spansMultipleMeasures == true)
    #expect(result.expressionEvents.isEmpty)
    #expect(result.slurEvents.isEmpty)
    #expect(result.tempoTimelineEvents.count == 2)
}

@Test func musicSheetReaderReadWithTraversalIncludesExpressionEvents() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(directionExpressionsXML))
    #expect(result.expressionEvents.count == 8)
    #expect(result.expressionEvents.contains {
        if case .dynamic("mf") = $0.value {
            return true
        }
        return false
    })
    #expect(result.slurEvents.isEmpty)
    #expect(result.tempoTimelineEvents.count == 2)
}

@Test func musicSheetReaderReadWithTraversalIncludesSlurEvents() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(crossMeasureSlurXML))
    #expect(result.slurEvents.count == 1)
    #expect(result.slurEvents[0].spansMultipleMeasures == true)
    #expect(result.slurEvents[0].isOpenEnded == false)
    #expect(result.tempoTimelineEvents.count == 2)
}

@Test func musicSheetReaderReadWithTraversalIncludesTempoTimelineEvents() throws {
    let reader = MusicSheetReader()
    let result = try reader.readWithTraversal(from: .xmlString(repeatsAndTempoXML))
    #expect(result.tempoTimelineEvents.count == 4)
    #expect(result.tempoTimelineEvents[2].absolutePosition == MDKFraction(1, 4))
}

@Test func parserReadsDivisionsNotesVoicesAndTimingDirectives() throws {
    let score = try MusicXMLParser().parse(xml: noteVoiceTimingXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.divisions == 4)
    #expect(measure.noteEvents.count == 3)
    #expect(measure.timingDirectives.count == 2)

    let first = measure.noteEvents[0]
    #expect(first.kind == .pitched)
    #expect(first.voice == 1)
    #expect(first.onsetDivisions == 0)
    #expect(first.durationDivisions == 4)
    #expect(first.pitch == PitchValue(step: "C", alter: 1, octave: 4))
    #expect(first.staff == nil)
    #expect(first.isChord == false)
    #expect(first.isGrace == false)

    let second = measure.noteEvents[1]
    #expect(second.kind == .rest)
    #expect(second.voice == 2)
    #expect(second.onsetDivisions == 0)
    #expect(second.durationDivisions == 4)

    let third = measure.noteEvents[2]
    #expect(third.kind == .pitched)
    #expect(third.pitch == PitchValue(step: "D", alter: 0, octave: 5))
    #expect(third.onsetDivisions == 0)
    #expect(third.durationDivisions == nil)
    #expect(third.isChord == true)
    #expect(third.isGrace == true)

    #expect(measure.timingDirectives[0] == TimingDirective(kind: .backup, durationDivisions: 4))
    #expect(measure.timingDirectives[1] == TimingDirective(kind: .forward, durationDivisions: 2))
}

@Test func parserReadsKeyTimeAndClefAttributes() throws {
    let score = try MusicXMLParser().parse(xml: measureAttributesXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.number == 10)
    #expect(measure.divisions == 8)

    let attributes = try #require(measure.attributes)
    #expect(attributes.key == KeySignature(fifths: -3, mode: "minor"))
    #expect(attributes.time == TimeSignature(beats: 4, beatType: 4, symbol: "common"))
    #expect(attributes.clefs.count == 2)
    #expect(attributes.clefs[0] == ClefSetting(sign: "G", line: 2, number: 1, octaveChange: nil))
    #expect(attributes.clefs[1] == ClefSetting(sign: "F", line: 4, number: 2, octaveChange: -1))
}

@Test func parserReadsLyricTieAndSlurMarkers() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.noteEvents.count == 2)

    let first = measure.noteEvents[0]
    #expect(first.lyrics == [LyricEvent(number: 1, text: "Hel", syllabic: "begin", extend: false)])
    #expect(first.ties.count == 2)
    #expect(first.ties[0] == TieMarker(type: .start, source: .tieElement))
    #expect(first.ties[1] == TieMarker(type: .start, source: .tiedNotation))
    #expect(first.slurs == [SlurMarker(type: .start, number: 1, placement: "above")])

    let second = measure.noteEvents[1]
    #expect(second.onsetDivisions == 2)
    #expect(second.lyrics == [LyricEvent(number: 1, text: "lo", syllabic: "end", extend: true)])
    #expect(second.ties.count == 2)
    #expect(second.ties[0] == TieMarker(type: .stop, source: .tieElement))
    #expect(second.ties[1] == TieMarker(type: .stop, source: .tiedNotation))
    #expect(second.slurs == [SlurMarker(type: .stop, number: 1, placement: nil)])

    #expect(measure.tieSpans == [
        TieSpan(
            startNoteIndex: 0,
            endNoteIndex: 1,
            source: .tieElement,
            voice: 1,
            staff: nil,
            pitch: PitchValue(step: "E", alter: 0, octave: 4)
        )
    ])
    #expect(measure.slurSpans == [
        SlurSpan(number: 1, startNoteIndex: 0, endNoteIndex: 1, voice: 1, staff: nil, placement: "above")
    ])
    #expect(measure.lyricWords == [
        LyricWord(number: 1, startNoteIndex: 0, endNoteIndex: 1, text: "Hello", hasExtension: true)
    ])
}

@Test func parserReadsBeamTupletAndTimeModificationMarkers() throws {
    let score = try MusicXMLParser().parse(xml: beamTupletXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.noteEvents.count == 2)

    let first = measure.noteEvents[0]
    #expect(first.beams == [BeamMarker(number: 1, value: .begin)])
    #expect(first.tuplets == [
        TupletMarker(
            type: .start,
            number: 1,
            bracket: true,
            placement: "below",
            showNumber: "both",
            showType: "actual"
        )
    ])
    #expect(first.timeModification == TimeModification(actualNotes: 3, normalNotes: 2))

    let second = measure.noteEvents[1]
    #expect(second.beams == [BeamMarker(number: 1, value: .end)])
    #expect(second.tuplets == [TupletMarker(type: .stop, number: 1)])
    #expect(second.timeModification == TimeModification(actualNotes: 3, normalNotes: 2))
}

@Test func parserReadsArticulationMarkers() throws {
    let score = try MusicXMLParser().parse(xml: articulationsXML)
    let measure = try #require(score.parts.first?.measures.first)
    let note = try #require(measure.noteEvents.first)

    #expect(note.articulations == [
        ArticulationMarker(kind: .staccato, placement: "above", type: nil),
        ArticulationMarker(kind: .strongAccent, placement: nil, type: "up")
    ])
}

@Test func parserReadsDirectionExpressionMarkers() throws {
    let score = try MusicXMLParser().parse(xml: directionExpressionsXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.directionEvents.count == 1)

    let direction = measure.directionEvents[0]
    #expect(direction.onsetDivisions == 6)
    #expect(direction.offsetDivisions == 2)
    #expect(direction.placement == "above")
    #expect(direction.staff == 1)
    #expect(direction.soundTempo == 120)
    #expect(direction.metronome == MetronomeMark(beatUnit: "quarter", beatUnitDotCount: 1, perMinute: "120", parentheses: true))
    #expect(direction.dynamics == ["mf"])
    #expect(direction.words == ["dolce"])
    #expect(direction.rehearsal == "A")
    #expect(direction.wedges == [
        WedgeMarker(type: .crescendo, number: 1, spread: 12, niente: false, lineType: "solid")
    ])
    #expect(direction.octaveShifts == [
        OctaveShiftMarker(type: .up, number: 1, size: 8)
    ])
    #expect(direction.pedals == [
        PedalMarker(type: .start, line: true, sign: false)
    ])
}

@Test func parserReadsHarmonyEvents() throws {
    let score = try MusicXMLParser().parse(xml: harmonyXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.harmonyEvents.count == 1)

    let harmony = measure.harmonyEvents[0]
    #expect(harmony.onsetDivisions == 2)
    #expect(harmony.offsetDivisions == 2)
    #expect(harmony.rootStep == "C")
    #expect(harmony.rootAlter == 1)
    #expect(harmony.kind == "major-seventh")
    #expect(harmony.kindText == "maj7")
    #expect(harmony.kindUsesSymbols == true)
    #expect(harmony.staff == 1)
    #expect(harmony.degrees == [
        HarmonyDegree(value: 9, alter: -1, type: .add)
    ])
}

@Test func parserReadsRepetitionInstructionsAndCalculatesTempoTimeline() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let part = try #require(score.parts.first)
    #expect(part.measures.count == 2)

    let m1 = part.measures[0]
    #expect(m1.repetitionInstructions.contains {
        $0.kind == .repeatForward && $0.location == "left"
    })
    #expect(m1.repetitionInstructions.contains {
        $0.kind == .endingStart && $0.location == "right" && $0.endingNumbers == [1]
    })
    #expect(m1.tempoEvents == [
        TempoEvent(onsetDivisions: 0, bpm: 120, source: .carryForward),
        TempoEvent(onsetDivisions: 0, bpm: 96, source: .sound)
    ])

    let m2 = part.measures[1]
    #expect(m2.repetitionInstructions.contains {
        $0.kind == .repeatBackward && $0.times == 2 && $0.location == "right"
    })
    #expect(m2.repetitionInstructions.contains {
        $0.kind == .endingStop && $0.endingNumbers == [1]
    })
    #expect(m2.repetitionInstructions.contains { $0.kind == .segno })
    #expect(m2.repetitionInstructions.contains { $0.kind == .coda })
    #expect(m2.repetitionInstructions.contains { $0.kind == .daCapo })
    #expect(m2.repetitionInstructions.contains { $0.kind == .dalSegno && $0.target == "seg1" })
    #expect(m2.repetitionInstructions.contains { $0.kind == .toCoda && $0.target == "coda1" })
    #expect(m2.repetitionInstructions.contains { $0.kind == .alCoda && $0.target == "coda1" })
    #expect(m2.repetitionInstructions.contains { $0.kind == .alFine })
    #expect(m2.repetitionInstructions.contains { $0.kind == .fine })
    #expect(m2.tempoEvents == [
        TempoEvent(onsetDivisions: 0, bpm: 96, source: .carryForward),
        TempoEvent(onsetDivisions: 0, bpm: 72, source: .metronome)
    ])

    let playback = try #require(part.playbackOrder)
    #expect(playback.termination == .fine)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2])
}

@Test func parserBuildsPlaybackOrderForRepeatEndings() throws {
    let score = try MusicXMLParser().parse(xml: repeatEndingPlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 3, 4])
}

@Test func parserBuildsPlaybackOrderForSequentialImplicitRepeatStarts() throws {
    let score = try MusicXMLParser().parse(xml: sequentialImplicitRepeatStartXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 3, 4, 3, 4])
}

@Test func parserTreatsRepeatTimesAsTotalIterationCount() throws {
    let score = try MusicXMLParser().parse(xml: repeatTimesAttributePlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 1, 2, 3])
}

@Test func parserTreatsRepeatTimesOneAsNoRepeat() throws {
    let score = try MusicXMLParser().parse(xml: repeatTimesOnePlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3])
}

@Test func parserClampsRepeatTimesZeroToNoRepeat() throws {
    let score = try MusicXMLParser().parse(xml: repeatTimesZeroPlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3])
}

@Test func parserClampsNegativeRepeatTimesToNoRepeat() throws {
    let score = try MusicXMLParser().parse(xml: repeatTimesNegativePlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3])
}

@Test func parserDefaultsBackwardRepeatToTwoTotalPlays() throws {
    let score = try MusicXMLParser().parse(xml: repeatTimesDefaultPlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 3])
}

@Test func parserDoesNotApplyEndingSkipsWithoutBackwardRepeat() throws {
    let score = try MusicXMLParser().parse(xml: endingWithoutBackwardRepeatXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2])
}

@Test func parserBuildsPlaybackOrderForDalSegnoAlCoda() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoAlCodaPlaybackXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 3, 4])
}

@Test func parserBuildsPlaybackOrderWithTargetedSegnoAndCoda() throws {
    let score = try MusicXMLParser().parse(xml: targetedDalSegnoToCodaXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3, 2, 3, 4, 6])
}

@Test func parserPrefersDalSegnoOverDaCapoWhenBothPresent() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoPrecedenceOverDaCapoXML)
    let measure2 = try #require(score.parts.first?.measures.dropFirst().first)
    #expect(measure2.repetitionInstructions.contains { $0.kind == .alFine })
    #expect(!measure2.repetitionInstructions.contains { $0.kind == .fine })

    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .fine)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3, 4])
}

@Test func parserParsesEndingNumberRanges() throws {
    let score = try MusicXMLParser().parse(xml: endingNumberRangeXML)
    let measure = try #require(score.parts.first?.measures.first)
    #expect(measure.repetitionInstructions.contains {
        $0.kind == .endingStart && $0.endingNumbers == [1, 2, 3, 5, 7]
    })
    #expect(measure.repetitionInstructions.contains {
        $0.kind == .endingStop && $0.endingNumbers == [1, 2, 3, 5, 7]
    })
}

@Test func parserDoesNotStopAtFineWithoutAlFine() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoAlCodaIgnoresFineXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 3, 4])
}

@Test func parserUsesForwardCodaTargetForToCodaJump() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoAlCodaUsesForwardCodaXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3, 2, 3, 4, 5])
}

@Test func parserAppliesToCodaOnJumpCommandMeasureAfterJumpExecution() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoAlCodaToCodaOnJumpMeasureXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 4])
}

@Test func parserBuildsPlaybackOrderForDalSegnoAlCodaWithRepeatEndings() throws {
    let score = try MusicXMLParser().parse(xml: dalSegnoAlCodaWithRepeatEndingsXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 3, 1, 4, 5, 6, 1, 4, 5, 6])
}

@Test func parserParsesOSMDRepetitionFixturesWithoutStepLimit() throws {
    let fixtures = [
        "test_staverepetitions_coda_etc.musicxml",
        "test_staverepetitions_coda_etc_positioning.musicxml",
        "test_voltas_interrupted_1615.musicxml",
        "test_repeat_left_barline_simple.musicxml",
        "OSMD_function_Test_Repeat.musicxml",
        "test_repeat_volta_simple.musicxml",
    ]
    let parser = MusicXMLParser()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let score = try parser.parse(fileURL: url)
        let part = try #require(score.parts.first)
        let playback = try #require(part.playbackOrder)

        #expect(playback.termination != .stepLimit)
        #expect(!playback.visits.isEmpty)
        #expect(!part.measures.flatMap(\.repetitionInstructions).isEmpty)
    }
}

@Test func parserParsesAdditionalOSMDRepeatAdjacentFixturesWithoutStepLimit() throws {
    let fixtures = [
        "OSMD_function_test_multiple_rest_measures.musicxml",
        "test_multiple_rest_measures_repeat_2_measures.musicxml",
        "test_multiple_rest_measures_repeat_3_measures.musicxml",
        "test_implicit_measure_repeat_singlenote.musicxml",
    ]
    let parser = MusicXMLParser()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let score = try parser.parse(fileURL: url)
        let part = try #require(score.parts.first)
        let playback = try #require(part.playbackOrder)

        #expect(playback.termination != .stepLimit)
        #expect(!playback.visits.isEmpty)
        #expect(playback.visits.count <= max(1, part.measures.count * 32))
    }
}

@Test func musicSheetReaderParsesOSMDExpressionAndTempoFixtures() throws {
    let fixtures = [
        "OSMD_function_test_expressions.musicxml",
        "test_tempo_expression_poco_meno_continuoustempoexpression.musicxml",
    ]
    let reader = MusicSheetReader()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let result = try reader.readWithTraversal(from: .fileURL(url))
        #expect(!result.expressionEvents.isEmpty)
        #expect(!result.tempoTimelineEvents.isEmpty)
    }
}

@Test func musicSheetReaderParsesOSMDChordSymbolFixtures() throws {
    let fixtures = [
        "OSMD_function_test_chord_symbols.musicxml",
        "test_chord_symbol_centering_short_symbols.musicxml",
    ]
    let reader = MusicSheetReader()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let result = try reader.readWithTraversal(from: .fileURL(url))
        #expect(!result.chordSymbols.isEmpty)
    }
}

@Test func musicSheetReaderParsesOSMDLyricsFixtures() throws {
    let fixtures = [
        "test_lyrics_centering.musicxml",
        "test_lyrics_spacing_short_notes_four_characters.musicxml",
    ]
    let reader = MusicSheetReader()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let result = try reader.readWithTraversal(from: .fileURL(url))
        #expect(!result.lyricWordEvents.isEmpty)
    }
}

@Test func musicSheetReaderParsesOSMDSlurFixtures() throws {
    let fixtures = [
        "test_slur_double.musicxml",
        "test_slurs_highNotes.musicxml",
    ]
    let reader = MusicSheetReader()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let result = try reader.readWithTraversal(from: .fileURL(url))
        #expect(!result.slurEvents.isEmpty)
    }
}

@Test func musicSheetReaderParsesOSMDArticulationFixtures() throws {
    let fixtures = [
        "test_articulation_staccato_placement_above_explicitly.musicxml",
        "test_articulation_staccato_placement_below.musicxml",
    ]
    let reader = MusicSheetReader()

    for fixture in fixtures {
        let url = try osmdFixtureURL(named: fixture)
        let result = try reader.readWithTraversal(from: .fileURL(url))
        #expect(!result.articulationEvents.isEmpty)
    }
}

@Test func musicSheetReaderParsesOSMDDirectionSpannerFixtures() throws {
    let reader = MusicSheetReader()

    let octaveShiftURL = try osmdFixtureURL(named: "test_octave-shift_simple_piano.musicxml")
    let octaveShiftResult = try reader.readWithTraversal(from: .fileURL(octaveShiftURL))
    #expect(octaveShiftResult.expressionEvents.contains {
        if case .octaveShift = $0.value {
            return true
        }
        return false
    })

    let pedalURL = try osmdFixtureURL(named: "test_pedal_signs.musicxml")
    let pedalResult = try reader.readWithTraversal(from: .fileURL(pedalURL))
    #expect(pedalResult.expressionEvents.contains {
        if case .pedal = $0.value {
            return true
        }
        return false
    })

    let wedgeURL = try osmdFixtureURL(named: "test_wedge_cresc_dim_simultaneous_quartet.musicxml")
    let wedgeResult = try reader.readWithTraversal(from: .fileURL(wedgeURL))
    #expect(wedgeResult.expressionEvents.contains {
        if case .wedge = $0.value {
            return true
        }
        return false
    })
}

@Test func musicSheetReaderParsesOSMDRehearsalAndTempoFixtures() throws {
    let reader = MusicSheetReader()

    let rehearsalURL = try osmdFixtureURL(named: "test_rehearsal_marks_simple_one_measure.musicxml")
    let rehearsalResult = try reader.readWithTraversal(from: .fileURL(rehearsalURL))
    #expect(rehearsalResult.expressionEvents.contains {
        if case .rehearsal = $0.value {
            return true
        }
        return false
    })

    let tempoChangeURL = try osmdFixtureURL(named: "test_tempo_change.musicxml")
    let tempoChangeResult = try reader.readWithTraversal(from: .fileURL(tempoChangeURL))
    #expect(tempoChangeResult.tempoTimelineEvents.count >= 2)

    let metronomeURL = try osmdFixtureURL(named: "OSMD_function_test_metronome_marks.mxl")
    let metronomeResult = try reader.readWithTraversal(from: .fileURL(metronomeURL))
    #expect(!metronomeResult.tempoTimelineEvents.isEmpty)
}

@Test func parserDoesNotFallbackToDifferentCodaWhenTargetMissing() throws {
    let score = try MusicXMLParser().parse(xml: targetedToCodaDoesNotFallbackToDifferentCodaXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 3, 4, 5, 6])
}

@Test func parserAllowsSoundToCodaFallbackWhenNoExplicitForwardMarkerExists() throws {
    let score = try MusicXMLParser().parse(xml: soundToCodaFallbackOnJumpMeasureXML)
    let playback = try #require(score.parts.first?.playbackOrder)
    #expect(playback.termination == .endOfScore)
    #expect(playback.visits.map(\.measureNumber) == [1, 2, 1, 2, 4])
}

@Test func parserRejectsNonPartwiseRoot() throws {
    let invalidXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-timewise></score-timewise>
    """
    #expect(throws: MusicXMLParserError.missingScorePartwise) {
        try MusicXMLParser().parse(xml: invalidXML)
    }
}

@Test func layoutEngineBuildsDeterministicGeometryForMinimalScore() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())

    #expect(laidOut.systems.count == 1)
    #expect(laidOut.measures.count == 2)
    #expect(laidOut.measures[0].frame == LayoutRect(x: 40, y: 40, width: 176, height: 72))
    #expect(laidOut.measures[1].frame == LayoutRect(x: 228, y: 40, width: 176, height: 72))
    #expect(laidOut.systems[0].measureIndices == [0, 1])
}

@Test func layoutEngineWrapsSystemsWhenPageWidthIsSmall() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let options = LayoutOptions(pageWidth: 300)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 2)
    #expect(laidOut.measures.count == 2)
    #expect(laidOut.measures[0].systemIndex == 0)
    #expect(laidOut.measures[0].frame == LayoutRect(x: 40, y: 40, width: 176, height: 72))
    #expect(laidOut.measures[1].systemIndex == 1)
    #expect(laidOut.measures[1].frame == LayoutRect(x: 40, y: 140, width: 176, height: 72))
}

@Test func layoutEngineScalesMeasureWidthFromTimeSignatureDuration() throws {
    let score = try MusicXMLParser().parse(xml: layoutTimeSignatureSpacingXML)
    let options = LayoutOptions(pageWidth: 600)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 1)
    #expect(laidOut.measures.count == 3)
    #expect(laidOut.measures.map { $0.frame.width } == [176, 88, 132])
}

@Test func layoutEngineBreaksToNextPageWhenHeightIsExceeded() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let options = LayoutOptions(pageWidth: 300, pageHeight: 200)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 2)
    #expect(laidOut.systems.map(\.pageIndex) == [0, 1])
    #expect(laidOut.measures.map(\.pageIndex) == [0, 1])
    #expect(laidOut.measures[0].frame == LayoutRect(x: 40, y: 40, width: 176, height: 72))
    #expect(laidOut.measures[1].frame == LayoutRect(x: 40, y: 40, width: 176, height: 72))
}

@Test func layoutEngineSynchronizesSystemBreaksAcrossParts() throws {
    let score = try MusicXMLParser().parse(xml: multiPartLayoutSynchronizationXML)
    let options = LayoutOptions(pageWidth: 500)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 4)
    #expect(laidOut.measures.count == 6)

    // Row 1: both parts share a 2-measure system segment with aligned x/width.
    #expect(laidOut.systems[0].partIndex == 0)
    #expect(laidOut.systems[0].frame.y == 40)
    #expect(laidOut.systems[0].measureIndices.count == 2)
    #expect(laidOut.systems[1].partIndex == 1)
    #expect(laidOut.systems[1].frame.y == 160)
    #expect(laidOut.systems[1].measureIndices.count == 2)

    let p1m1 = try #require(laidOut.measures.first { $0.partIndex == 0 && $0.measureIndexInPart == 0 })
    let p2m1 = try #require(laidOut.measures.first { $0.partIndex == 1 && $0.measureIndexInPart == 0 })
    #expect(p1m1.frame.x == p2m1.frame.x)
    #expect(p1m1.frame.width == p2m1.frame.width)
    #expect(p1m1.frame.width == 176)

    #expect(laidOut.partGroups.count == 2)
    #expect(laidOut.partGroups.allSatisfy { $0.symbol == .brace })
    #expect(laidOut.partGroups.allSatisfy { $0.startPartIndex == 0 && $0.endPartIndex == 1 })
    #expect(laidOut.partGroups.map(\.frame.x) == [20, 20])
    #expect(laidOut.partGroups.map(\.frame.height) == [192, 192])
    #expect(laidOut.partGroups.map(\.nestingLevel) == [0, 0])

    #expect(laidOut.barlineConnectors.count == 4)
    #expect(laidOut.barlineConnectors.map(\.side) == [.left, .right, .left, .right])
    #expect(laidOut.barlineConnectors.map(\.frame.x) == [40, 404, 40, 216])
}

@Test func layoutEnginePageBreaksWholeRowsForMultiPartSystems() throws {
    let score = try MusicXMLParser().parse(xml: multiPartLayoutSynchronizationXML)
    let options = LayoutOptions(pageWidth: 500, pageHeight: 350)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 4)
    #expect(laidOut.systems.map(\.pageIndex) == [0, 0, 1, 1])

    let firstRowMeasures = laidOut.measures.filter { $0.measureIndexInPart <= 1 }
    let secondRowMeasures = laidOut.measures.filter { $0.measureIndexInPart == 2 }
    #expect(firstRowMeasures.allSatisfy { $0.pageIndex == 0 })
    #expect(secondRowMeasures.allSatisfy { $0.pageIndex == 1 })

    #expect(laidOut.partGroups.count == 2)
    #expect(laidOut.partGroups.map(\.pageIndex) == [0, 1])
    #expect(laidOut.partGroups.map(\.frame.y) == [40, 40])
    #expect(laidOut.barlineConnectors.map(\.pageIndex) == [0, 0, 1, 1])
}

@Test func layoutEnginePlacesNestedPartGroupsWithStackedOffsets() throws {
    let score = try MusicXMLParser().parse(xml: nestedPartGroupLayoutXML)
    let options = LayoutOptions(pageWidth: 500)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: options)

    #expect(laidOut.systems.count == 3)
    #expect(laidOut.partGroups.count == 2)

    let outer = try #require(laidOut.partGroups.first(where: { $0.number == 1 }))
    let inner = try #require(laidOut.partGroups.first(where: { $0.number == 2 }))

    #expect(outer.symbol == .bracket)
    #expect(inner.symbol == .brace)
    #expect(outer.startPartIndex == 0 && outer.endPartIndex == 2)
    #expect(inner.startPartIndex == 0 && inner.endPartIndex == 1)
    #expect(outer.nestingLevel == 1)
    #expect(inner.nestingLevel == 0)
    #expect(outer.frame.x < inner.frame.x)
    #expect(outer.frame.width == 10)
    #expect(inner.frame.width == 12)

    // Only outer group has barline-join enabled.
    #expect(laidOut.barlineConnectors.count == 2)
    #expect(laidOut.barlineConnectors.map(\.side) == [.left, .right])
    #expect(laidOut.barlineConnectors.allSatisfy { $0.sourceGroupIndex == outer.sourceGroupIndex })
}

@Test func layoutEngineAppliesSameSpanGroupPriorityAndRenderMetadata() throws {
    let score = try MusicXMLParser().parse(xml: sameSpanPartGroupOrderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 500))
    #expect(laidOut.partGroups.count == 2)

    let bracket = try #require(laidOut.partGroups.first(where: { $0.symbol == .bracket }))
    let brace = try #require(laidOut.partGroups.first(where: { $0.symbol == .brace }))

    // Same-span policy: bracket renders outside (farther left) and earlier.
    #expect(bracket.startPartIndex == brace.startPartIndex)
    #expect(bracket.endPartIndex == brace.endPartIndex)
    #expect(bracket.nestingLevel > brace.nestingLevel)
    #expect(bracket.frame.x < brace.frame.x)
    #expect(bracket.renderOrder < brace.renderOrder)

    // Renderer handoff metadata should be symbol-specific.
    #expect(bracket.renderStyle.hookLength > 0)
    #expect(bracket.renderStyle.curvature == 0)
    #expect(brace.renderStyle.hookLength == 0)
    #expect(brace.renderStyle.curvature > 0)
    #expect(brace.renderStyle.strokeWidth > bracket.renderStyle.strokeWidth)

    // Only the barline-enabled (bracket) group emits row connectors.
    #expect(laidOut.barlineConnectors.count == 2)
    #expect(laidOut.barlineConnectors.map(\.side) == [.left, .right])
    #expect(laidOut.barlineConnectors.allSatisfy { $0.sourceGroupIndex == bracket.sourceGroupIndex })
}

@Test func vexAdapterBuildsRenderPlanFromLayoutMetadata() throws {
    let score = try MusicXMLParser().parse(xml: sameSpanPartGroupOrderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 500))
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.pageCount == 1)
    #expect(plan.canvasWidth == 500)
    #expect(plan.canvasHeight == 272)
    #expect(plan.staves.count == laidOut.systems.count)
    #expect(plan.measures.count == laidOut.measures.count)
    #expect(plan.measureBoundaries.count == laidOut.measures.count)
    #expect(plan.notes.isEmpty)
    #expect(plan.beams.isEmpty)
    #expect(plan.tuplets.isEmpty)
    #expect(plan.ties.isEmpty)
    #expect(plan.slurs.isEmpty)
    #expect(plan.articulations.isEmpty)
    #expect(plan.lyrics.isEmpty)
    #expect(plan.chordSymbols.isEmpty)
    #expect(plan.directionTexts.isEmpty)
    #expect(plan.tempoMarks.isEmpty)
    #expect(plan.roadmapRepetitions.isEmpty)
    #expect(plan.directionWedges.isEmpty)
    #expect(plan.octaveShiftSpanners.isEmpty)
    #expect(plan.pedalMarkings.isEmpty)
    #expect(plan.lyricConnectors.isEmpty)
    #expect(plan.partGroupConnectors.count == laidOut.partGroups.count)
    #expect(plan.barlineConnectors.count == 2)

    let bracketConnector = try #require(plan.partGroupConnectors.first(where: { $0.kind == .bracket }))
    let braceConnector = try #require(plan.partGroupConnectors.first(where: { $0.kind == .brace }))
    #expect(bracketConnector.renderOrder < braceConnector.renderOrder)
    #expect(bracketConnector.style.hookLength > 0)
    #expect(braceConnector.style.curvature > 0)

    #expect(plan.barlineConnectors.map(\.kind) == [.singleLeft, .singleRight])
    #expect(plan.barlineConnectors.allSatisfy { $0.sourceGroupIndex == bracketConnector.sourceGroupIndex })
}

@Test func vexAdapterImageTargetOverridesCanvasSize() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(
        from: laidOut,
        target: .image(width: 1024, height: 768)
    )

    #expect(plan.canvasWidth == 1024)
    #expect(plan.canvasHeight == 768)
    #expect(plan.pageCount == 1)
}

@Test func vexAdapterCarriesInitialStaveAttributesIntoPlan() throws {
    let score = try MusicXMLParser().parse(xml: measureAttributesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let stave = try #require(plan.staves.first)

    #expect(stave.startMeasureNumber == 10)
    #expect(stave.initialClef == "treble")
    #expect(stave.initialClefAnnotation == nil)
    #expect(stave.initialKeySignature == "Cm")
    #expect(stave.initialTimeSignature == "C")
}

@Test func vexAdapterBuildsSingleVoiceNotePlans() throws {
    let score = try MusicXMLParser().parse(xml: singleVoiceRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 5)
    #expect(plan.notes.filter { $0.isRest }.count == 1)
    #expect(plan.notes.allSatisfy { $0.partIndex == 0 })
    #expect(Set(plan.notes.map(\.voice)) == Set([1, 2]))
    #expect(plan.notes.contains { $0.keyTokens.contains("e#/4") })
    #expect(plan.notes.map(\.measureIndexInPart).sorted() == [0, 0, 0, 0, 1])
}

@Test func vexAdapterBuildsChordGroupedNotePlans() throws {
    let score = try MusicXMLParser().parse(xml: multiVoiceChordRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 3)
    let chordCandidates = plan.notes.filter { $0.voice == 1 && $0.onsetDivisions == 0 }
    let chord = try #require(chordCandidates.first)
    #expect(chord.isRest == false)
    #expect(chord.keyTokens == ["c/4", "e/4"])
    #expect(plan.notes.contains { $0.voice == 2 && $0.keyTokens == ["g/3"] })
}

@Test func vexAdapterBuildsBeamAndTupletPlans() throws {
    let score = try MusicXMLParser().parse(xml: beamTupletRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 3)
    #expect(plan.beams.count == 1)
    #expect(plan.tuplets.count == 1)

    let beam = try #require(plan.beams.first)
    #expect(beam.voice == 1)
    #expect(beam.startEntryIndex == 0)
    #expect(beam.endEntryIndex == 2)

    let tuplet = try #require(plan.tuplets.first)
    #expect(tuplet.voice == 1)
    #expect(tuplet.startEntryIndex == 0)
    #expect(tuplet.endEntryIndex == 2)
    #expect(tuplet.numNotes == 3)
    #expect(tuplet.notesOccupied == 2)
    #expect(tuplet.bracketed == true)
    #expect(tuplet.ratioed == true)
    #expect(tuplet.location == .top)
}

@Test func vexAdapterBuildsTieAndSlurPlans() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 2)
    #expect(plan.ties.count == 1)
    #expect(plan.slurs.count == 1)

    let tie = try #require(plan.ties.first)
    #expect(tie.voice == 1)
    #expect(tie.startEntryIndex == 0)
    #expect(tie.endEntryIndex == 1)
    #expect(tie.pitchToken == "e/4")

    let slur = try #require(plan.slurs.first)
    #expect(slur.voice == 1)
    #expect(slur.number == 1)
    #expect(slur.startEntryIndex == 0)
    #expect(slur.endEntryIndex == 1)
    #expect(slur.placement == "above")
}

@Test func vexAdapterBuildsArticulationPlans() throws {
    let score = try MusicXMLParser().parse(xml: articulationsXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 1)
    #expect(plan.articulations.count == 2)

    let codes = Set(plan.articulations.map(\.articulationCode))
    #expect(codes == Set(["a.", "a^"]))
    #expect(plan.articulations.allSatisfy { $0.entryIndexInVoice == 0 })
    #expect(plan.articulations.allSatisfy { $0.position == .above })
}

@Test func vexAdapterBuildsLyricPlans() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.notes.count == 2)
    #expect(plan.lyrics.count == 2)
    #expect(plan.lyrics.map(\.text) == ["Hel", "lo"])
    #expect(plan.lyrics.map(\.verse) == [1, 1])
    #expect(plan.lyrics.map(\.entryIndexInVoice) == [0, 1])
    #expect(plan.lyricConnectors.count == 1)
    let connector = try #require(plan.lyricConnectors.first)
    #expect(connector.kind == .hyphen)
    #expect(connector.verse == 1)
    #expect(connector.startEntryIndexInVoice == 0)
    #expect(connector.endEntryIndexInVoice == 1)
}

@Test func vexAdapterBuildsChordSymbolPlans() throws {
    let score = try MusicXMLParser().parse(xml: harmonyXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.chordSymbols.count == 1)
    let chordSymbol = try #require(plan.chordSymbols.first)
    #expect(chordSymbol.displayText == "C#maj7(addb9)")
    #expect(chordSymbol.voice == 1)
    #expect(chordSymbol.entryIndexInVoice == 0)
}

@Test func vexAdapterBuildsDirectionTextPlans() throws {
    let score = try MusicXMLParser().parse(xml: directionRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.directionTexts.count == 3)
    let texts = Set(plan.directionTexts.map(\.text))
    #expect(texts == Set(["mf", "dolce", "A"]))
    #expect(plan.directionTexts.allSatisfy { $0.voice == 1 })
    #expect(plan.directionTexts.allSatisfy { $0.entryIndexInVoice == 0 })
    #expect(plan.directionTexts.allSatisfy { $0.placement == .above })
}

@Test func vexAdapterDefaultsDynamicDirectionTextPlacementBelowWhenUnspecified() throws {
    let score = try MusicXMLParser().parse(xml: directionDynamicDefaultPlacementXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.directionTexts.count == 1)
    let dynamic = try #require(plan.directionTexts.first)
    #expect(dynamic.text == "mf")
    #expect(dynamic.placement == .below)
}

@Test func vexAdapterBuildsDirectionTempoMarkPlans() throws {
    let score = try MusicXMLParser().parse(xml: directionTempoRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.tempoMarks.count == 2)
    let firstTempo = plan.tempoMarks[0]
    #expect(firstTempo.voice == 1)
    #expect(firstTempo.entryIndexInVoice == 0)
    #expect(firstTempo.bpm == 120)
    #expect(firstTempo.duration == .quarter)
    #expect(firstTempo.dots == 1)

    let secondTempo = plan.tempoMarks[1]
    #expect(secondTempo.voice == 1)
    #expect(secondTempo.entryIndexInVoice == 1)
    #expect(secondTempo.bpm == 96)
    #expect(secondTempo.duration == .quarter)
    #expect(secondTempo.dots == 0)
}

@Test func vexAdapterBuildsRoadmapRepetitionPlans() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.roadmapRepetitions.count == 5)
    let kinds = Set(plan.roadmapRepetitions.map(\.kind))
    #expect(kinds.contains(.segnoLeft))
    #expect(kinds.contains(.codaLeft))
    #expect(kinds.contains(.dsAlCoda))
    #expect(kinds.contains(.toCoda))
    #expect(kinds.contains(.fine))
}

@Test func vexAdapterBuildsDirectionExpressionSpannerPlans() throws {
    let score = try MusicXMLParser().parse(xml: directionSpanRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.directionWedges.count == 1)
    let wedge = try #require(plan.directionWedges.first)
    #expect(wedge.kind == .crescendo)
    #expect(wedge.voice == 1)
    #expect(wedge.startEntryIndexInVoice == 0)
    #expect(wedge.endEntryIndexInVoice == 1)
    #expect(wedge.placement == .below)

    #expect(plan.octaveShiftSpanners.count == 1)
    let octaveShift = try #require(plan.octaveShiftSpanners.first)
    #expect(octaveShift.voice == 1)
    #expect(octaveShift.startEntryIndexInVoice == 0)
    #expect(octaveShift.endEntryIndexInVoice == 1)
    #expect(octaveShift.text == "8")
    #expect(octaveShift.superscript == "va")
    #expect(octaveShift.position == .top)

    #expect(plan.pedalMarkings.count == 1)
    let pedal = try #require(plan.pedalMarkings.first)
    #expect(pedal.voice == 1)
    #expect(pedal.startEntryIndexInVoice == 0)
    #expect(pedal.endEntryIndexInVoice == 1)
    #expect(pedal.kind == .bracket)
}

@Test func vexAdapterBuildsLyricExtenderConnectorPlans() throws {
    let score = try MusicXMLParser().parse(xml: lyricExtenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    #expect(plan.lyricConnectors.count == 1)
    let connector = try #require(plan.lyricConnectors.first)
    #expect(connector.kind == .extender)
    #expect(connector.verse == 1)
    #expect(connector.startEntryIndexInVoice == 0)
    #expect(connector.endEntryIndexInVoice == 2)
}

@Test func vexAdapterBuildsCrossMeasureLyricHyphenConnectorPlans() throws {
    let score = try MusicXMLParser().parse(xml: crossMeasureLyricsXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))

    let hyphen = try #require(plan.lyricConnectors.first(where: { $0.kind == .hyphen }))
    #expect(hyphen.startMeasureIndexInPart == 0)
    #expect(hyphen.endMeasureIndexInPart == 1)
    #expect(hyphen.startEntryIndexInVoice == 0)
    #expect(hyphen.endEntryIndexInVoice == 0)
    #expect(hyphen.verse == 1)
}

@Test func vexAdapterCarriesRepeatBarlineStylesIntoStavePlan() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let plan = VexFoundationRenderer().makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let stave = try #require(plan.staves.first)

    #expect(stave.beginBarline == .repeatBegin)
    #expect(stave.endBarline == .repeatEnd)
}

@Test func vexAdapterExecutesRenderPlanIntoFactoryObjects() throws {
    let score = try MusicXMLParser().parse(xml: nestedPartGroupLayoutXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 500))
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.staves.count == plan.staves.count)
    #expect(execution.notes.isEmpty)
    #expect(execution.voices.isEmpty)
    #expect(execution.beams.isEmpty)
    #expect(execution.tuplets.isEmpty)
    #expect(execution.ties.isEmpty)
    #expect(execution.slurs.isEmpty)
    #expect(execution.articulations.isEmpty)
    #expect(execution.lyrics.isEmpty)
    #expect(execution.chordSymbols.isEmpty)
    #expect(execution.directionTexts.isEmpty)
    #expect(execution.tempoMarks.isEmpty)
    #expect(execution.roadmapRepetitions.isEmpty)
    #expect(execution.directionWedges.isEmpty)
    #expect(execution.octaveShiftSpanners.isEmpty)
    #expect(execution.pedalMarkings.isEmpty)
    #expect(execution.lyricConnectors.isEmpty)
    #expect(execution.measureBarlineConnectors.count == plan.measureBoundaries.count)
    #expect(execution.partGroupConnectors.count == plan.partGroupConnectors.count)
    #expect(execution.barlineConnectors.count == plan.barlineConnectors.count)

    for (connector, boundaryPlan) in zip(execution.measureBarlineConnectors, plan.measureBoundaries) {
        let anchorX = connector.topStave.getX() + connector.getXShift()
        #expect(abs(anchorX - boundaryPlan.x) < 0.0001)
    }

    for (connector, connectorPlan) in zip(execution.partGroupConnectors, plan.partGroupConnectors) {
        let anchorX: Double
        switch connectorPlan.kind {
        case .singleRight:
            anchorX = connector.topStave.getX() + connector.topStave.getWidth() + connector.getXShift()
        case .singleLeft, .brace, .bracket:
            anchorX = connector.topStave.getX() + connector.getXShift()
        }
        #expect(abs(anchorX - connectorPlan.frame.x) < 0.0001)
    }

    for (connector, connectorPlan) in zip(execution.barlineConnectors, plan.barlineConnectors) {
        let anchorX: Double
        switch connectorPlan.kind {
        case .singleRight:
            anchorX = connector.topStave.getX() + connector.topStave.getWidth() + connector.getXShift()
        case .singleLeft, .brace, .bracket:
            anchorX = connector.topStave.getX() + connector.getXShift()
        }
        #expect(abs(anchorX - connectorPlan.frame.x) < 0.0001)
    }

    let labels = Set(
        execution.partGroupConnectors
            .compactMap { connector in connector.texts.first?.content }
    )
    #expect(labels == Set(["Ensemble", "Manuals"]))
}

@Test func vexAdapterAppliesInitialStaveAttributesDuringExecution() throws {
    let score = try MusicXMLParser().parse(xml: measureAttributesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)
    let stave = try #require(execution.staves.first)

    #expect(stave.getMeasure() == 10)
    #expect(stave.getClef().rawValue == "treble")

    let beginModifierCategories = Set(stave.getModifiers(position: .begin).map { $0.getCategory() })
    #expect(beginModifierCategories.contains("Clef"))
    #expect(beginModifierCategories.contains("KeySignature"))
    #expect(beginModifierCategories.contains("TimeSignature"))
}

@Test func vexAdapterExecutesSingleVoiceNotesIntoVoices() throws {
    let score = try MusicXMLParser().parse(xml: singleVoiceRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.notes.count == plan.notes.count)
    #expect(execution.voices.count == 3)
    #expect(execution.notes.filter { $0.getNoteType() == "r" }.count == 1)
}

@Test func vexAdapterExecutesChordGroupedNotesIntoStaveNotes() throws {
    let score = try MusicXMLParser().parse(xml: multiVoiceChordRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.notes.count == 3)
    #expect(execution.voices.count == 2)
    #expect(execution.notes.contains { $0.getKeys().count == 2 })
    let pitchedStemDirections = Set(
        execution.notes
            .filter { !$0.isRest() }
            .map { $0.getStemDirection() }
    )
    #expect(pitchedStemDirections == Set([.up, .down]))
}

@Test func vexAdapterExecutesBeamAndTupletObjects() throws {
    let score = try MusicXMLParser().parse(xml: beamTupletRenderNotesXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.beams.count == 1)
    #expect(execution.tuplets.count == 1)

    let beam = try #require(execution.beams.first)
    #expect(beam.getNotes().count == 3)

    let tuplet = try #require(execution.tuplets.first)
    #expect(tuplet.getNoteCount() == 3)
    #expect(tuplet.getNotesOccupied() == 2)
    #expect(tuplet.bracketed == true)
    #expect(tuplet.ratioed == true)
    #expect(tuplet.location == .top)
}

@Test func vexAdapterExecutesTieAndSlurObjects() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.ties.count == 1)
    #expect(execution.slurs.count == 1)

    let tie = try #require(execution.ties.first)
    let tieNotes = tie.getNotes()
    #expect(tieNotes.firstNote != nil)
    #expect(tieNotes.lastNote != nil)
    #expect(tieNotes.firstIndices == [0])
    #expect(tieNotes.lastIndices == [0])

    let slur = try #require(execution.slurs.first)
    #expect(slur.from != nil)
    #expect(slur.to != nil)
    #expect(slur.renderOptions.invert == true)
}

@Test func vexAdapterExecutesArticulationObjects() throws {
    let score = try MusicXMLParser().parse(xml: articulationsXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.articulations.count == 2)
    let codes = Set(execution.articulations.map(\.type))
    #expect(codes == Set(["a.", "a^"]))
    #expect(execution.articulations.allSatisfy { $0.getPosition() == .above })

    let firstNote = try #require(execution.notes.first)
    #expect(firstNote.getModifiersByType("Articulation").count == 2)
}

@Test func vexAdapterExecutesLyricAnnotations() throws {
    let score = try MusicXMLParser().parse(xml: lyricTieSlurXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.lyrics.count == 2)
    #expect(execution.lyrics.map(\.text) == ["Hel", "lo"])
    #expect(execution.lyrics.allSatisfy { $0.verticalJustification == .bottom })
    #expect(execution.lyrics.allSatisfy { $0.getPosition() == .below })
    #expect(execution.lyrics.allSatisfy { $0.textLine == 0 })
    #expect(execution.notes.map { $0.getModifiersByType("Annotation").count } == [2, 1])
    #expect(execution.lyricConnectors.count == 1)
    let connector = try #require(execution.lyricConnectors.first)
    #expect(connector.text == "-")
    #expect(connector.textLine == 0)
    #expect(connector.getPosition() == .below)
}

@Test func vexAdapterExecutesLyricExtenderAnnotations() throws {
    let score = try MusicXMLParser().parse(xml: lyricExtenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.lyricConnectors.count == 1)
    let extender = try #require(execution.lyricConnectors.first)
    #expect(extender.text.contains("_"))
    #expect(extender.text.count >= 2)
    #expect(extender.textLine == 0)
    #expect(extender.getPosition() == .below)
}

@Test func vexAdapterExecutesChordSymbolModifiers() throws {
    let score = try MusicXMLParser().parse(xml: harmonyXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.chordSymbols.count == 1)
    let chordSymbol = try #require(execution.chordSymbols.first)
    #expect(chordSymbol.getVertical() == .top)
    #expect(chordSymbol.getHorizontal() == .center)
    #expect(execution.notes.first?.getModifiersByType("ChordSymbol").count == 1)
}

@Test func vexAdapterExecutesDirectionTextAnnotations() throws {
    let score = try MusicXMLParser().parse(xml: directionRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.directionTexts.count == 3)
    let texts = Set(execution.directionTexts.map(\.text))
    #expect(texts == Set(["mf", "dolce", "A"]))
    #expect(execution.directionTexts.allSatisfy { $0.verticalJustification == .top })
    #expect(execution.directionTexts.allSatisfy { $0.getPosition() == .above })

    let firstNote = try #require(execution.notes.first)
    #expect(firstNote.getModifiersByType("Annotation").count == 3)
}

@Test func vexAdapterExecutesDynamicDirectionTextBelowWhenUnspecified() throws {
    let score = try MusicXMLParser().parse(xml: directionDynamicDefaultPlacementXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.directionTexts.count == 1)
    let dynamic = try #require(execution.directionTexts.first)
    #expect(dynamic.text == "mf")
    #expect(dynamic.verticalJustification == .bottom)
    #expect(dynamic.getPosition() == .below)
}

@Test func vexAdapterExecutesDirectionTempoMarks() throws {
    let score = try MusicXMLParser().parse(xml: directionTempoRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.tempoMarks.count == 2)

    let firstTempo = execution.tempoMarks[0]
    #expect(firstTempo.tempo.bpm == 120)
    #expect(firstTempo.tempo.duration == .quarter)
    #expect(firstTempo.tempo.dots == 1)

    let secondTempo = execution.tempoMarks[1]
    #expect(secondTempo.tempo.bpm == 96)
    #expect(secondTempo.tempo.duration == .quarter)
    #expect(secondTempo.tempo.dots == 0)

    let firstStave = try #require(execution.staves.first)
    let tempoModifiers = firstStave.getModifiers().filter { $0.getCategory() == "StaveTempo" }
    #expect(tempoModifiers.count == 2)
}

@Test func vexAdapterExecutesRoadmapRepetitions() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.roadmapRepetitions.count == 5)
    let kinds = Set(execution.roadmapRepetitions.map(\.symbolType))
    #expect(kinds.contains(.segnoLeft))
    #expect(kinds.contains(.codaLeft))
    #expect(kinds.contains(.dsAlCoda))
    #expect(kinds.contains(.toCoda))
    #expect(kinds.contains(.fine))

    let firstStave = try #require(execution.staves.first)
    let repetitionModifiers = firstStave.getModifiers().filter { $0.getCategory() == "Repetition" }
    #expect(repetitionModifiers.count == 5)
}

@Test func vexAdapterExecutesDirectionExpressionSpanners() throws {
    let score = try MusicXMLParser().parse(xml: directionSpanRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.directionWedges.count == 1)
    let wedge = try #require(execution.directionWedges.first)
    #expect(wedge.hairpinType == .crescendo)
    #expect(wedge.hairpinPosition == .below)
    #expect(wedge.firstNote != nil)
    #expect(wedge.lastNote != nil)

    #expect(execution.octaveShiftSpanners.count == 1)
    let octaveShift = try #require(execution.octaveShiftSpanners.first)
    #expect(octaveShift.text == "8")
    #expect(octaveShift.superscriptText == "va")
    #expect(octaveShift.bracketPosition == .top)

    #expect(execution.pedalMarkings.count == 1)
    let pedal = try #require(execution.pedalMarkings.first)
    #expect(pedal.pedalType == .bracket)
    #expect(pedal.notes.count == 2)
}

@Test func vexAdapterSeparatesMultiVoiceLyricsByTextLine() throws {
    let score = try MusicXMLParser().parse(xml: multiVoiceLyricsXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)

    #expect(execution.lyrics.count == 2)
    #expect(execution.lyricConnectors.isEmpty)

    let textLinesByText = Dictionary(uniqueKeysWithValues: execution.lyrics.map { ($0.text, $0.textLine) })
    let highLine = try #require(textLinesByText["High"])
    let lowLine = try #require(textLinesByText["Low"])
    #expect(highLine == 0)
    #expect(lowLine > highLine)
}

@Test func vexAdapterAppliesRepeatBarlineStylesDuringExecution() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let renderer = VexFoundationRenderer()
    let plan = renderer.makeRenderPlan(from: laidOut, target: .view(identifier: "preview"))
    let execution = renderer.executeRenderPlan(plan)
    let stave = try #require(execution.staves.first)

    let beginBarline = try #require(
        stave.getModifiers(position: .begin, category: "Barline").first as? Barline
    )
    let endBarline = try #require(
        stave.getModifiers(position: .end, category: "Barline").first as? Barline
    )
    #expect(beginBarline.getBarlineType() == .repeatBegin)
    #expect(endBarline.getBarlineType() == .repeatEnd)
}

@Test func vexAdapterRenderExecutesHeadlessDraw() throws {
    let score = try MusicXMLParser().parse(xml: nestedPartGroupLayoutXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 500))
    try VexFoundationRenderer().render(laidOut, target: .view(identifier: "preview"))
}

@Test func vexAdapterRenderExecutesDirectionExpressionHeadlessDraw() throws {
    let score = try MusicXMLParser().parse(xml: directionSpanRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    try VexFoundationRenderer().render(laidOut, target: .view(identifier: "preview"))
}

@Test func vexAdapterRenderExecutesDirectionTempoHeadlessDraw() throws {
    let score = try MusicXMLParser().parse(xml: directionTempoRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    try VexFoundationRenderer().render(laidOut, target: .view(identifier: "preview"))
}

@Test func vexAdapterRenderExecutesRoadmapRepetitionHeadlessDraw() throws {
    let score = try MusicXMLParser().parse(xml: repeatsAndTempoXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    try VexFoundationRenderer().render(laidOut, target: .view(identifier: "preview"))
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderPNGDataWithoutLoadThrows() throws {
    let engine = MusicDisplayEngine()
    #expect(throws: MusicDisplayEngineError.noScoreLoaded) {
        _ = try engine.renderPNGData()
    }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderPNGDataRequiresCapableRenderer() throws {
    let engine = MusicDisplayEngine(renderer: NoOpScoreRenderer())
    try engine.load(xml: directionTempoRenderXML)

    #expect(throws: MusicDisplayEngineError.rendererDoesNotSupportImageExport) {
        _ = try engine.renderPNGData()
    }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func vexScoreViewInitializesFromLaidOutScore() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let view = VexScoreView(laidOutScore: laidOut, targetIdentifier: "preview")
    #expect(String(describing: view).contains("VexScoreView"))
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func musicDisplayScoreViewInitializesFromScore() throws {
    let score = try MusicXMLParser().parse(xml: minimalScoreXML)
    let view = MusicDisplayScoreView(score: score, layoutOptions: LayoutOptions(pageWidth: 500))
    #expect(String(describing: view).contains("MusicDisplayScoreView"))
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func vexAdapterRenderPNGDataProducesPNGBytes() throws {
    let score = try MusicXMLParser().parse(xml: directionTempoRenderXML)
    let laidOut = try MusicLayoutEngine().layout(score: score, options: LayoutOptions())
    let data = try VexFoundationRenderer().renderPNGData(
        from: laidOut,
        target: .image(width: 520, height: 220),
        scale: 1.0
    )

    #expect(data.count > 0)
    #expect(Array(data.prefix(8)) == pngSignaturePrefix)
}
#endif

@Test func engineRenderAfterLoadCompletes() throws {
    let engine = MusicDisplayEngine()
    try engine.load(xml: minimalScoreXML)
    try engine.render(target: .view(identifier: "preview"))
}

@Test func engineLoadMXLFileURLThenRenderCompletes() throws {
    let engine = MusicDisplayEngine()
    let data = try makeMXLArchiveData()

    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mxl")
    defer { try? FileManager.default.removeItem(at: tmpURL) }
    try data.write(to: tmpURL)

    try engine.load(fileURL: tmpURL)
    try engine.render(target: .view(identifier: "preview"))
}

@Test func engineLoadSourceThenRenderCompletes() throws {
    let engine = MusicDisplayEngine()
    try engine.load(source: .xmlString(minimalScoreXML))
    try engine.render(target: .view(identifier: "preview"))
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func engineRenderPNGDataAfterLoadCompletes() throws {
    let engine = MusicDisplayEngine()
    try engine.load(xml: directionTempoRenderXML)
    let data = try engine.renderPNGData(target: .image(width: 520, height: 220), scale: 1.0)

    #expect(data.count > 0)
    #expect(Array(data.prefix(8)) == pngSignaturePrefix)
}
#endif
