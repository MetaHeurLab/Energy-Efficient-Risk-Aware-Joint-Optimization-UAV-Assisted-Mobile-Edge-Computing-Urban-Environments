function root=application_research_root
roots=java.io.File.listRoots();root='';
for k=1:numel(roots)
 candidate=char(roots(k).getPath());
 if strcmpi(candidate(1),'D'),root=fullfile(candidate,'Codex');break,end
end
assert(~isempty(root),'SelectedApp:ResearchDrive','The preferred research drive is unavailable.');
end