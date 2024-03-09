https://retro64.altervista.org/blog/commodore-64-sid-music-programming-with-basic-playing-a-note/


10 S=0 :REG = 212 :DAT=213
15 A=2^(1/12)
20 F0=7454
25 N=-9
30 NF=INT(F0*A^N)
35 FH=INT(NF/256) :FL=NF-256*FH
40 OUT REG,S: OUT DAT,FL
45 WF=32
50 OUT REG,S+5: OUT DAT,13*16+5
55 OUT REG,S+6: OUT DAT,12*16+10
60 OUT REG,S+24: OUT DAT,15
65 DR=2000
70 OUT REG,S+4: OUT DAT,WF+1
75 FOR T=1 TO DR :NEXT
80 OUT REG,S+4: OUT DAT,WF


The note being played can be changed by adjusting the value of line 25. For instance, if you want to play a C5, you will just need to assign N the value 3. In facts, C5 is 3 half-tones past A4. Changing the value of N to 5 will play a D5 note instead.

Envelope parameters are set on lines 50 and 55. All parameters range from 0 to 15, but as we already know attack and sustain values are multiplied by 16. In facts, they live in the highest four bits of their register.

The duration of a note is the amount of time the gate bit is maintained set to on. This value is set on line 65.

On line 70, the gate bit is set to on. The attack phase starts. In other words, the note starts.

After the duration loop on line 75 ends, line 80 starts the release phase by turning off the gate bit. The piano key is released. The note does not disappear instantly, as we have a value of 10 for the release parameter (please see again line 55). You may try to change the release value to 0. Then, the note will stop instantly.

This program uses the sawtooth waveform. To hear the triangle waveform, replace the value of WF with 16 (line 45).
