function root=application_root
root=fileparts(mfilename('fullpath'));
[~,name]=fileparts(root);if strcmp(name,'src'),root=fileparts(root);end
end