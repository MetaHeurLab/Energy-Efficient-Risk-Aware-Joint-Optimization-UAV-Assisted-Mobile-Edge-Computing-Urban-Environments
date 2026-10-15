function proof=APP_ITERATION_PROOF(action,iteration,population,best)
% One native-generation witness; an optional getter reads the live observer best.
persistent state observerGetter
if isempty(state),state=struct('Count',0,'Indices',[],'Population',[],'NativeBest',[],'ObserverBest',[]);end
switch action
 case 'reset'
  state=struct('Count',0,'Indices',[],'Population',[],'NativeBest',[],'ObserverBest',[]);
  observerGetter=[];
  if nargin>=2,assert(isa(iteration,'function_handle'));observerGetter=iteration;end
 case 'mark'
  assert(isnumeric(iteration)&&isscalar(iteration)&&isfinite(iteration)&&iteration==state.Count+1, ...
   'SelectedApp:IterationOrder','Native generation marks must be sequential.');
  assert(isnumeric(population)&&isscalar(population)&&isfinite(population)&&population>=1&&population==round(population));
  assert(isnumeric(best)&&isscalar(best)&&isreal(best));
  state.Count=state.Count+1;state.Indices(end+1)=iteration;
  state.Population(end+1)=population;state.NativeBest(end+1)=best;
  if isempty(observerGetter),observed=NaN;else,observed=observerGetter();end
  assert(isnumeric(observed)&&isscalar(observed)&&isreal(observed));
  state.ObserverBest(end+1)=observed;
 case 'get'
 otherwise,error('SelectedApp:ProofAction','Unknown iteration witness action.');
end
proof=state;
end
