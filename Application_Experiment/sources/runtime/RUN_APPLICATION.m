% Press F5: run the complete fixed-population-input, fixed-generation study.
% Data and temporary files are physically stored on the research drive.
% Plotting is a separate step in PLOT_APPLICATION.m.
clc
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'algorithms'));
run_application_study('full');
