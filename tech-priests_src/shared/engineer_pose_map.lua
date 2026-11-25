-- Native Factorio 2.1.25 armed-walking atlas selection.
-- Measured from all 128 aim/walk pairs in the actual headed screenshots:
-- https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45693121355
-- Decoder: tools/run_engineer_pose_probe.py (exact marker-border alignment).
-- Corrected native result SHA256: be14b59f93a84bb4652eece12231a41e4f95d395adc153390ecd2f73b1ad8b35
-- Axes: [aim + 1][walk + 1], N, NE, E, SE, S, SW, W, NW; atlas rows are zero-based.
return {
  sample_frame_count=22, reverse_frame_sum=21,
  [18]={
    row={
      {0,1,2,1,0,1,2,1},
      {4,5,6,3,4,5,6,3},
      {7,8,9,10,7,8,9,10},
      {14,11,12,13,14,11,12,13},
      {17,16,15,16,17,16,15,16},
      {14,13,12,11,14,13,12,11},
      {7,10,9,8,7,10,9,8},
      {4,3,6,5,4,3,6,5},
    },
    mirrored={
      {false,false,false,true,false,false,false,true},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,true,false,false,false,true,false,false},
      {true,true,true,true,true,true,true,true},
      {true,true,true,true,true,true,true,true},
      {true,true,true,true,true,true,true,true},
    },
    reversed={
      {false,false,false,true,true,true,true,false},
      {false,false,false,false,true,true,true,true},
      {false,false,false,false,true,true,true,true},
      {true,true,false,false,false,false,true,true},
      {true,true,false,false,false,false,true,true},
      {true,true,true,false,false,false,false,true},
      {false,true,true,true,true,false,false,false},
      {false,true,true,true,true,false,false,false},
    },
  },
  [40]={
    row={
      {0,1,2,3,0,1,4,3},
      {8,5,6,7,8,5,6,9},
      {14,13,10,11,12,13,10,11},
      {16,19,18,15,16,17,18,15},
      {20,21,24,23,20,21,22,23},
      {28,25,26,29,28,25,26,27},
      {32,33,30,31,34,33,30,31},
      {36,37,38,35,36,39,38,35},
    },
    mirrored={
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
      {false,false,false,false,false,false,false,false},
    },
    reversed={
      {false,false,false,true,true,true,false,false},
      {false,false,false,false,true,true,true,false},
      {false,false,false,false,false,true,true,true},
      {true,false,false,false,false,false,true,true},
      {true,true,false,false,false,false,false,true},
      {true,true,true,false,false,false,false,false},
      {false,true,true,true,false,false,false,false},
      {false,false,true,true,true,false,false,false},
    },
  },
}
