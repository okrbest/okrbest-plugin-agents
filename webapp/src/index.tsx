// Copyright (c) 2023-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React from 'react';
import {Store, Action} from 'redux';
import styled from 'styled-components';
import {FormattedMessage} from 'react-intl';

import {GlobalState} from '@mattermost/types/store';

//@ts-ignore it exists
import aiIcon from '../../assets/bot_icon.png';

import manifest from '@/manifest';

import {LLMBotPost} from './components/llmbot_post';
import PostMenu from './components/post_menu';
import IconThreadSummarization from './components/assets/icon_thread_summarization';
import IconReactForMe from './components/assets/icon_react_for_me';
import RHS from './components/rhs/rhs';
import Config from './components/system_console/config';
import {doReaction, doRunSearch, doThreadAnalysis, getAIDirectChannel} from './client';
import {setOpenRHSAction} from './redux_actions';
import PostEventListener from './websocket';
import {BotsHandler, setupRedux} from './redux';
import UnreadsSummarize from './components/unreads_summarize';
import {PostbackPost} from './components/postback_post';
import {isRHSCompatable} from './mm_webapp';
import SearchButton from './components/search_button';
import {doSelectPost} from './hooks';
import {handleAskChannelCommand, handleSummarizeChannelCommand} from './commands';
import SearchHints from './components/search_hints';

type WebappStore = Store<GlobalState, Action<Record<string, unknown>>>

const IconAIContainer = styled.img`
	border-radius: 50%;
    width: 24px;
    height: 24px;
`;

const RHSTitleContainer = styled.span`
    display: flex;
	gap: 8px;
    align-items: center;
	margin-left: 8px;
`;

const RHSTitle = () => {
    return (
        <RHSTitleContainer>
            <IconAIContainer src={aiIcon}/>
            {'Agents'}
        </RHSTitleContainer>
    );
};

export default class Plugin {
    postEventListener: PostEventListener = new PostEventListener();

    // eslint-disable-next-line @typescript-eslint/no-unused-vars, @typescript-eslint/no-empty-function
    public async initialize(registry: any, store: WebappStore) {
        setupRedux(registry, store);

        registry.registerTranslations((locale: string) => {
            try {
                // eslint-disable-next-line global-require
                return require(`./i18n/${locale}.json`);
            } catch (e) {
                return {};
            }
        });

        let rhs: any = null;
        if (isRHSCompatable()) {
            rhs = registry.registerRightHandSidebarComponent(RHS, RHSTitle);
            setOpenRHSAction(rhs.showRHSPlugin);
        }

        let currentUserId = store.getState().entities.users.currentUserId;
        if (currentUserId) {
            getAIDirectChannel(currentUserId).then((botChannelId) => {
                store.dispatch({type: 'SET_AI_BOT_CHANNEL', botChannelId} as any);
            });
        }

        store.subscribe(() => {
            const state = store.getState();
            if (state && state.entities.users.currentUserId !== currentUserId) {
                currentUserId = state.entities.users.currentUserId;
                if (currentUserId) {
                    getAIDirectChannel(currentUserId).then((botChannelId) => {
                        store.dispatch({type: 'SET_AI_BOT_CHANNEL', botChannelId} as any);
                    });
                } else {
                    store.dispatch({type: 'SET_AI_BOT_CHANNEL', botChannelId: ''} as any);
                }
            }
        });

        // Handle all post-related websocket events with one handler
        registry.registerWebSocketEventHandler('custom_mattermost-ai_postupdate', this.postEventListener.handlePostUpdateWebsockets);
        registry.registerWebSocketEventHandler('custom_mattermost-ai_tool_call_status_updated', this.postEventListener.handlePostUpdateWebsockets);

        const LLMBotPostWithWebsockets = (props: any) => {
            return (
                <LLMBotPost
                    {...props}
                    websocketRegister={this.postEventListener.registerPostUpdateListener}
                    websocketUnregister={this.postEventListener.unregisterPostUpdateListener}
                />
            );
        };

        registry.registerWebSocketEventHandler('config_changed', () => {
            store.dispatch({
                type: BotsHandler,
                bots: null,
            } as any);
        });

        registry.registerPostTypeComponent('custom_llmbot', LLMBotPostWithWebsockets);
        registry.registerPostTypeComponent('custom_llm_postback', PostbackPost);
        if (registry.registerPostActionComponent) {
            registry.registerPostActionComponent(PostMenu);
        } else {
            registry.registerPostDropdownMenuAction(<><span className='icon'><IconThreadSummarization/></span><FormattedMessage defaultMessage='Summarize Thread'/></>, (postId: string) => {
                const state = store.getState();
                const team = state.entities.teams.teams[state.entities.teams.currentTeamId];
                window.WebappUtils.browserHistory.push('/' + team.name + '/messages/@ai');
                doThreadAnalysis(postId, 'summarize_thread', '');
                if (rhs) {
                    store.dispatch(rhs.showRHSPlugin);
                }
            });
            registry.registerPostDropdownMenuAction(<><span className='icon'><IconReactForMe/></span><FormattedMessage defaultMessage='React for me'/></>, doReaction);
        }

        registry.registerAdminConsoleCustomSetting('Config', Config);
        if (rhs) {
            registry.registerChannelHeaderButtonAction(<IconAIContainer src={aiIcon}/>, () => {
                store.dispatch(rhs.toggleRHSPlugin);
            },
            'Agents',
            'Agents',
            );
        }

        if (registry.registerNewMessagesSeparatorActionComponent) {
            registry.registerNewMessagesSeparatorActionComponent(UnreadsSummarize);
        }

        // Register slash commands
        if (rhs) {
            registry.registerSlashCommandWillBePostedHook((message: string, args: any) => {
                if (message.startsWith('/ask-channel')) {
                    const query = message.replace('/ask-channel', '').trim();
                    return handleAskChannelCommand(query, args, store, rhs);
                } else if (message.startsWith('/summarize-channel')) {
                    const commandParams = message.replace('/summarize-channel', '').trim();
                    return handleSummarizeChannelCommand(commandParams, args, store, rhs);
                }
                return {message, args};
            });
        }

        if (registry.registerSearchComponents) {
            // The SearchButton and SearchHints components will check if search is enabled
            registry.registerSearchComponents({
                buttonComponent: SearchButton,
                suggestionsComponent: () => null,
                hintsComponent: SearchHints,
                action: async (searchTerms: string) => {
                    // Get the active bot from the state
                    const state = store.getState() as any;
                    const bots = state['plugins-' + manifest.id]?.bots || [];
                    const activeBotUsername = localStorage.getItem('defaultBot') || '';
                    const activeBot = bots.find((bot: any) => bot.username === activeBotUsername);

                    const result = await doRunSearch(
                        searchTerms,
                        '',
                        '',
                        activeBot?.username,
                    );
                    doSelectPost(result.postid, result.channelid, store.dispatch);
                    if (rhs) {
                        store.dispatch(rhs.showRHSPlugin);
                    }
                },
            });
        }
    }
}

declare global {
    interface Window {
        registerPlugin(pluginId: string, plugin: Plugin): void
        WebappUtils?: any
    }
}

window.registerPlugin(manifest.id, new Plugin());
