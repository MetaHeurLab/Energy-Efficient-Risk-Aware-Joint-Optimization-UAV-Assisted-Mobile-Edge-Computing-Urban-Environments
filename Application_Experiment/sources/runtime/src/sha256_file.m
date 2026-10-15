function hex=sha256_file(path)
% Hash only the explicitly named file; do not inspect unrelated settings.
fid=fopen(path,'rb'); assert(fid>=0,'GPC130:File','Cannot open %s.',path);
cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    digest.update(bytes);
end
hex=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
clear cleanup
end
