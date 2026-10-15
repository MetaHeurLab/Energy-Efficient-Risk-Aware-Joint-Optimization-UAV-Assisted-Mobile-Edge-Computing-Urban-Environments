function func_plot_cec2022(F,dim)
% Plot the raw two-coordinate slice; remaining coordinates are held at zero.
[lb,ub,~,objective] = Get_Functions_cec2022(F,dim);
coordinates = linspace(lb(1),ub(1),101);
[x1,x2] = meshgrid(coordinates,coordinates);
z = zeros(size(x1));
for i = 1:numel(z)
    z(i) = objective([x1(i) x2(i) zeros(1,dim-2)]);
end
surfc(x1,x2,z,'LineStyle','none');
xlabel('x_1'); ylabel('x_2'); zlabel('F(x_1,x_2)');
title(sprintf('F%d',F));
end
