function distance=segment_clearance(path,centers)
% Exact distance to complete closed segments, including zero-length segments.
segment=diff(path); norm2=sum(segment.^2,2);
distance=zeros(size(centers,1),size(path,1)-1);
for j=1:size(centers,1)
    vector=centers(j,:)-path(1:end-1,:);
    fraction=min(1,max(0,sum(vector.*segment,2)./max(norm2,realmin)));
    nearest=path(1:end-1,:)+fraction.*segment;
    distance(j,:)=vecnorm(nearest-centers(j,:),2,2)';
end
end
