package org.forrest.keycloak.http;

import java.io.IOException;

import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.utils.StringUtil;

import okhttp3.Response;

public class HeaderForwardingInterceptor implements okhttp3.Interceptor {

    private final String[] headersToForward;
    private final KeycloakSession session;

    public HeaderForwardingInterceptor(KeycloakSession session, ComponentModel model) {
        this.headersToForward = model.getConfig().getList("headers_to_forward")
            .stream()
            .filter(header -> !StringUtil.isNullOrEmpty(header))
            .toArray(String[]::new);
        this.session = session;
    }

    @Override
    public Response intercept(Chain chain) throws IOException {
        var request = chain.request();
        
        if (headersToForward.length == 0)
            return chain.proceed(request);

        var keycloakRequest = session.getContext().getHttpRequest();
        if (keycloakRequest == null)
            return chain.proceed(request);

        var keycloakRequestHeaders = keycloakRequest.getHttpHeaders();
            
        var requestBuilder = request.newBuilder();
        for (String header : headersToForward) {
            String value = keycloakRequestHeaders.getHeaderString(header);
            if (value != null)
                requestBuilder.addHeader(header, value);
        }

        return chain.proceed(requestBuilder.build());
    }
}
