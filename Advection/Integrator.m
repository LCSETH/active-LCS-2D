%% References:
%%
% function [xt,yt] = Integrator(x0,y0,tspan,options)

% Input arguments:
%   x0,y0: x- and y-components of the initial positions
%   tspan: time span for advecting particles 
%   options: options structure for ordinary differential equation solvers

% Output arguments:
%   xt: x-component of Lagrangian trajectories - size: [#times,#particles]
%   yt: y-component of Lagrangian trajectories - size: [#times,#particles]
function [xt,yt] = Integrator(x0,y0,tspan,NCores,options,diffusion,tstep,methodInterp)
Np = numel(x0);               % number of particles
x0 = x0(:); y0 = y0(:);
%% Computing the final positions of the Lagrangian particles:
if NCores == 1

    [~,F] = ode45(@ODEfun,tspan,[x0;y0],options,tstep,methodInterp);
    if diffusion
        xt = F(:,1:end/2);
        yt = F(:,end/2+1:end);
    else
        xt = F(end,1:end/2);
        yt = F(end,end/2+1:end);
    end
    
else
    cpu_num = min(NCores,Np);
    id = ceil( linspace(0,Np,cpu_num+1) );
    %- Opening MATLAB Pool
    poolobj = gcp('nocreate'); % If no pool, do not create new one.
    l = 'local';
    if isempty(poolobj)                                          % if parpool is not open
        evalc('parpool(l,cpu_num)');
    elseif (~isempty(poolobj)) && (poolobj.NumWorkers~=cpu_num)  % if parpool is not consistent with cpu_num
        delete(gcp)
        evalc('parpool(l,cpu_num)');
    end
    spmd
        Range = id(labindex)+1:id(labindex+1);
        [~,F] = ode45(@ODEfun,tspan,[x0(Range);y0(Range)],options,tstep,methodInterp);
        
        if diffusion
            xt = F(:,1:end/2);
            yt = F(:,end/2+1:end);
        else
            xt = F(end,1:end/2);
            yt = F(end,end/2+1:end);
        end
        
    end
    
    xt = cat(2,xt{:});
    yt = cat(2,yt{:});
    
end
end


function dy = ODEfun(t,y,tstep,methodInterp)
    
    % load the grid over which the velocity is saved
    xi = linspace(0,2*pi,1025);
    yi = linspace(0,2*pi,1025);

    N=round(length(y)/2);
    y(1:N,1)     = wrapTo2Pi(y(1:N,1));
    y(N+1:2*N,1) = wrapTo2Pi(y(N+1:2*N,1));
    
    % Interpolate velocity in time and space
    [u1_vec, u2_vec]= interp_vel(t,y,xi,yi);
    dy = zeros(2*N,1);    % a column vector
    dy(1:N,1) = u1_vec(1:N,1);
    dy(N+1:2*N,1) = u2_vec(1:N,1);
    
        function [u_vec, v_vec]=interp_vel(t,y,xi,yi)
        N=round(length(y)/2);
        % load velocity data
        k=floor(t/tstep);
        [ui, vi]=read_vel(k);
        [uf, vf]=read_vel(k+1);
        
        %linear interpolation in time
        u_t = ((k+1)*tstep-t)/tstep*ui + (t-k*tstep)/tstep*uf;
        v_t = ((k+1)*tstep-t)/tstep*vi + (t-k*tstep)/tstep*vf;

        %spline interpolation in space
        u_interp = griddedInterpolant({xi,yi},u_t,methodInterp,'none');
        v_interp = griddedInterpolant({xi,yi},v_t,methodInterp,'none');
        u_vec = u_interp(y(1:N,1),y(N+1:2*N,1));
        v_vec = v_interp(y(1:N,1),y(N+1:2*N,1));
        
            function [v1, v2]=read_vel(k)
            
            str1 = '../Data/turb_u_'; 
            str2 = pad(int2str(k),4,'left','0');
            str = strcat(str1,str2);
            load(str);
            [n1, n2]=size(u1);
            v1=zeros(n1+1,n2+1); v2=zeros(n1+1,n2+1);
            v1 = [u1 u1(:,1)]; v1=[v1; v1(1,:)]';
            v2 = [u2 u2(:,1)]; v2=[v2; v2(1,:)]';
            end
        end
end
