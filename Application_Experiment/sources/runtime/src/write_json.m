function write_json(path,value)
fid=fopen(path,'w','n','UTF-8');
assert(fid>=0,'GPC130:File','Cannot write %s.',path);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
clear cleanup
end
